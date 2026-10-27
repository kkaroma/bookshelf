# "My year in books": one member's reading, rating and swapping in a year.
# Private to that member - built only for Current.user.
class YearInBooks
  attr_reader :user, :year

  Swap = Data.define(:received, :gave, :with, :completed_at)

  def initialize(user, year)
    @user = user
    @year = year.to_i
  end

  def dates = Date.new(year).all_year
  def times = Time.zone.local(year).all_year

  # --- Reading ---

  def books_read = user.books.read.where(finished_on: dates).order(:finished_on, :id)
  def read_count = @read_count ||= books_read.count

  def by_month
    ReportBar.monthly(books_read.pluck(:finished_on), last_month: Date.new(year, 12, 1))
  end

  def busiest_month
    month = by_month.max_by(&:count)
    month if month&.count.to_i.positive?
  end

  def goal = user.reading_goal_for(year)

  # { "Fantasy" => 4, "History" => 2 } - the most-read genres, top 3
  def top_genres
    books_read.reorder(nil).where.not(genre: nil).group(:genre).count.sort_by { |genre, count| [ -count, genre ] }.first(3).to_h
  end

  # The book read in the fewest days (needs both dates).
  def quickest_read
    books_read.where.not(started_on: nil).min_by { |book| [ book.finished_on - book.started_on, book.id ] }
  end

  # --- Everything else ---

  def books_added = user.books.where(created_at: times).count
  def reviews_written = user.books.where(reviewed_at: times).count
  def comments_written = user.comments.where(created_at: times).count

  def ratings = user.ratings.where(created_at: times)

  # Their highest-rated book this year (the latest one, if several tie).
  def favourite_rating
    ratings.includes(:book).order(score: :desc, created_at: :desc).first
  end

  def swaps
    ExchangeRequest.completed.where(completed_at: times)
                   .where("exchange_requests.requester_id = :id OR exchange_requests.owner_id = :id", id: user.id)
                   .includes(:book, :offered_book, :requester, :owner).order(:completed_at)
                   .map do |swap|
                     mine = swap.requester_id == user.id
                     Swap.new(received: mine ? swap.book : swap.offered_book,
                              gave: mine ? swap.offered_book : swap.book,
                              with: mine ? swap.owner : swap.requester,
                              completed_at: swap.completed_at)
                   end
  end

  def anything?
    read_count.positive? || books_added.positive? || ratings.exists? || swaps.any?
  end

  # Years worth showing: this one, plus every year they finished or added a book.
  def available_years
    finished = user.books.where.not(finished_on: nil).distinct.pluck(Arel.sql("EXTRACT(YEAR FROM finished_on)::int"))
    added = user.books.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM created_at)::int"))
    (finished + added + [ Date.current.year ]).uniq.sort.reverse
  end
end
