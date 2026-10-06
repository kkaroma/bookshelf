require "csv"

# Turns a Goodreads "Export Library" CSV file into books on a member's shelf.
#
#   result = GoodreadsImport.new(user: Current.user, csv: file.read, shelves: %w[read]).run
#   result.imported  # the new books
#
# Books already on the member's shelf (same ISBN, or same title and author) are
# skipped, and so are books on Goodreads shelves the member didn't choose.
# Covers are fetched afterwards in the background (FetchCoverJob).
class GoodreadsImport
  # Goodreads' "Exclusive Shelf" values, with the names we show.
  SHELVES = { "read" => "Read", "currently-reading" => "Currently reading", "to-read" => "Want to read" }.freeze
  DEFAULT_SHELVES = %w[ read currently-reading ].freeze
  MAX_ROWS = 2_000
  COVER_JOB_SPACING = 5.seconds # spread Open Library lookups out (its ISBN search allows ~100 per 5 minutes)

  class InvalidFile < StandardError; end

  Result = Data.define(:imported, :duplicates, :other_shelves, :invalid)

  def initialize(user:, csv:, shelves:)
    @user = user
    @csv = csv
    @shelves = Array(shelves) & SHELVES.keys
  end

  def run
    imported = []
    duplicates = other_shelves = invalid = 0
    seen_isbns, seen_titles = existing_keys

    Book.transaction do
      rows.each do |row|
        shelf = row["Exclusive Shelf"].presence || "read"
        unless @shelves.include?(shelf)
          other_shelves += 1
          next
        end

        attributes = attributes_from(row)
        title_key = [ attributes[:title], attributes[:author] ].map { |value| value.to_s.downcase.squish }
        if (attributes[:isbn] && seen_isbns.include?(attributes[:isbn])) || seen_titles.include?(title_key)
          duplicates += 1
          next
        end

        book = @user.books.build(attributes)
        if book.save
          imported << book
          seen_isbns << book.isbn if book.isbn
          seen_titles << title_key
        else
          invalid += 1
        end
      end
    end

    fetch_covers_later(imported)
    Result.new(imported:, duplicates:, other_shelves:, invalid:)
  end

  private
    def rows
      text = @csv.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete_prefix("﻿")
      table = CSV.parse(text, headers: true)
      unless (%w[ Title Author ] - table.headers.compact).empty?
        raise InvalidFile, "That file doesn't look like a Goodreads export (it has no Title and Author columns)."
      end
      table.first(MAX_ROWS)
    rescue CSV::MalformedCSVError
      raise InvalidFile, "That file couldn't be read as a CSV spreadsheet."
    end

    def existing_keys
      books = @user.books.pluck(:isbn, :title, :author)
      [ books.filter_map(&:first).to_set,
        books.map { |_isbn, title, author| [ title, author ].map { |value| value.to_s.downcase.squish } }.to_set ]
    end

    def attributes_from(row)
      title, subtitle = split_title(row["Title"])
      {
        title: title,
        subtitle: subtitle,
        author: row["Author"].to_s.squish.presence,
        isbn: isbn_from(row["ISBN13"]) || isbn_from(row["ISBN"]),
        published_year: year_from(row["Original Publication Year"]) || year_from(row["Year Published"]),
        review: review_from(row["My Review"])
      }
    end

    # "Dune (Dune, #1)" -> "Dune";  "Sapiens: A Brief History" -> ["Sapiens", "A Brief History"]
    def split_title(raw)
      title = raw.to_s.squish.sub(/\s*\([^()]*#\d+(\.\d+)?\)\z/, "")
      main, subtitle = title.split(": ", 2)
      [ main.presence || title, subtitle.presence ]
    end

    # Goodreads writes ISBNs as ="9780547928227" so spreadsheets keep the digits.
    def isbn_from(value)
      digits = value.to_s.upcase.gsub(/[^0-9X]/, "")
      digits if Book.valid_isbn?(digits)
    end

    def year_from(value)
      year = value.to_s[/\d{1,4}/].to_i
      year if year.between?(1, Date.current.year)
    end

    # Reviews come as HTML ("Line one<br/><br/>Line two"); keep the line breaks, drop the tags.
    def review_from(html)
      text = html.to_s.gsub(/<br\s*\/?>/i, "\n")
      ActionController::Base.helpers.strip_tags(text).gsub(/\n{3,}/, "\n\n").strip.presence
    end

    def fetch_covers_later(books)
      books.select(&:isbn).each_with_index do |book, index|
        FetchCoverJob.set(wait: index * COVER_JOB_SPACING).perform_later(book)
      end
    end
end
