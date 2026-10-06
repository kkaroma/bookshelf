require "test_helper"

class GoodreadsImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @alice = users(:one) # already has The Hobbit
    @csv = file_fixture("goodreads_library_export.csv").read
  end

  def import(shelves: GoodreadsImport::DEFAULT_SHELVES, csv: @csv)
    GoodreadsImport.new(user: @alice, csv: csv, shelves: shelves).run
  end

  test "imports read and currently-reading books, skipping duplicates and bad rows" do
    result = import

    assert_equal [ "Sapiens", "Dune" ], result.imported.map(&:title)
    assert_equal 1, result.duplicates     # The Hobbit is already on Alice's shelf
    assert_equal 1, result.other_shelves  # Project Hail Mary is "to-read"
    assert_equal 1, result.invalid        # Mystery Pamphlet has no author
    assert result.imported.all? { |book| book.user == @alice }
  end

  test "maps Goodreads columns onto books" do
    sapiens, dune = import.imported

    assert_equal "A Brief History of Humankind", sapiens.subtitle # "Title: Subtitle" is split
    assert_equal "Yuval Noah Harari", sapiens.author
    assert_equal "9780062316097", sapiens.isbn                     # ="…" wrapper removed, ISBN-13 preferred
    assert_equal 2011, sapiens.published_year                      # original publication year
    assert_equal "Fascinating.\n\nRead it twice.", sapiens.review  # line breaks kept, HTML removed

    assert_equal "Dune", dune.title                                # "(Dune, #1)" series removed
    assert_nil dune.subtitle
    assert_equal 1965, dune.published_year
    assert_nil dune.review
  end

  test "Goodreads shelves become reading statuses, with the date read" do
    sapiens, dune = import.imported
    assert sapiens.read?
    assert_equal Date.new(2024, 5, 20), sapiens.finished_on
    assert dune.reading?
    assert_nil dune.finished_on

    want = import(shelves: %w[ to-read ]).imported.first
    assert want.want_to_read?
  end

  test "you choose which shelves to import" do
    result = import(shelves: %w[ to-read ])
    assert_equal [ "Project Hail Mary" ], result.imported.map(&:title)
    assert_nil result.imported.first.isbn # the export had no ISBN for it
  end

  test "importing the same file twice adds nothing the second time" do
    import
    result = import
    assert_empty result.imported
    assert_equal 3, result.duplicates
  end

  test "covers are fetched in the background, spread out, for books with an ISBN" do
    assert_enqueued_jobs 2, only: FetchCoverJob do
      import
    end
  end

  test "a file that isn't a Goodreads export is refused" do
    error = assert_raises(GoodreadsImport::InvalidFile) { import(csv: "name,email\nAda,ada@example.com\n") }
    assert_match "doesn't look like a Goodreads export", error.message
  end

  test "a broken CSV file is refused" do
    assert_raises(GoodreadsImport::InvalidFile) { import(csv: %(Title,Author\n"unclosed quote,Someone\n)) }
  end
end
