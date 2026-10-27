# Admin → Swaps: how swapping is going, and what people want versus what's
# offered. Read-only, like AdminReport.
class SwapReport
  include ReportCsv

  TOP = 10
  ANSWERED = %w[accepted declined completed].freeze
  # When a book went on the shelf (older books, listed before this was recorded, use when they were added).
  LISTED_AT = "COALESCE(books.listed_for_exchange_at, books.created_at)".freeze

  Wanted = Data.define(:title, :author, :wanted_by, :on_shelf)

  attr_reader :period

  def initialize(period: ReportPeriod.new(nil))
    @period = period
  end

  # --- Requests in the period ---

  def requests = ExchangeRequest.where(created_at: period.range)
  def requests_count = requests.count

  # { "pending" => 3, "accepted" => 1, ... } including zeros
  def requests_by_status
    counts = requests.group(:status).count
    ExchangeRequest.statuses.keys.index_with { |status| counts.fetch(status, 0) }
  end

  # Of the requests owners answered, how many they said yes to (cancelled
  # and still-pending requests don't count either way). nil if none answered.
  def acceptance_rate
    by_status = requests_by_status
    answered = ANSWERED.sum { |status| by_status[status] }
    return if answered.zero?

    (100.0 * (by_status["accepted"] + by_status["completed"]) / answered).round
  end

  # Typical (median) time from asking to the owner's answer, in seconds.
  def median_answer_seconds
    requests.where(status: ANSWERED).where.not(responded_at: nil)
            .pick(Arel.sql("percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM responded_at - created_at))"))
            &.to_f
  end

  def completed_count = ExchangeRequest.completed.where(completed_at: period.range).count

  # --- Right now ---

  def waiting = ExchangeRequest.pending
  def oldest_waiting = waiting.includes(:requester, :owner, :book).order(:created_at).first

  # --- Last 12 months, month by month ---

  def requests_by_month
    ReportBar.monthly(ExchangeRequest.where(created_at: twelve_months).pluck(:created_at), last_month: period.now)
  end

  def completed_by_month
    ReportBar.monthly(ExchangeRequest.completed.where(completed_at: twelve_months).pluck(:completed_at), last_month: period.now)
  end

  # --- Supply and demand (right now) ---

  # The books most members have on their wishlist, and how many copies are
  # on the Exchange shelf. Wishes are grouped by title, ignoring capitals.
  def most_wanted(limit: TOP)
    rows = WishlistItem.group(Arel.sql("LOWER(wishlist_items.title)"))
                       .order(Arel.sql("COUNT(DISTINCT wishlist_items.user_id) DESC"), Arel.sql("LOWER(wishlist_items.title)"))
                       .limit(limit)
                       .pluck(Arel.sql("LOWER(wishlist_items.title)"), Arel.sql("MIN(wishlist_items.title)"),
                              Arel.sql("MIN(wishlist_items.author)"), Arel.sql("COUNT(DISTINCT wishlist_items.user_id)"),
                              Arel.sql("ARRAY_REMOVE(ARRAY_AGG(DISTINCT wishlist_items.isbn), NULL)"))

    rows.map do |key, title, author, wanted_by, isbns|
      on_shelf = Book.for_exchange.where("LOWER(books.title) = ?", key).or(Book.for_exchange.where(isbn: isbns)).count
      Wanted.new(title:, author:, wanted_by:, on_shelf:)
    end
  end

  # Books on the Exchange shelf that nobody has asked for since they were
  # listed, longest-waiting first.
  def unrequested_books(limit: TOP)
    unrequested_scope.includes(:user).order(Arel.sql(LISTED_AT)).limit(limit)
  end

  def unrequested_count = unrequested_scope.count

  def self.listed_at(book) = book.listed_for_exchange_at || book.created_at

  private
    def twelve_months
      (period.now.beginning_of_month - 11.months)..period.now
    end

    def unrequested_scope
      Book.for_exchange.where(<<~SQL.squish)
        NOT EXISTS (SELECT 1 FROM exchange_requests
                    WHERE exchange_requests.book_id = books.id
                      AND exchange_requests.created_at >= #{LISTED_AT})
      SQL
    end

    def csv_rows
      rows = [
        [ "Report", "Period", period.label ],
        [ "Requests", "Requests made", requests_count ],
        [ "Requests", "Acceptance rate (%)", acceptance_rate ],
        [ "Requests", "Typical time to answer (hours)", median_answer_seconds&.then { |s| (s / 3600).round(1) } ],
        [ "Requests", "Swaps completed", completed_count ],
        [ "Requests", "Waiting for an answer now", waiting.count ]
      ]
      requests_by_status.each { |status, count| rows << [ "Requests by result", status.humanize, count ] }
      requests_by_month.each { |bar| rows << [ "Requests per month", bar.long_label, bar.count ] }
      completed_by_month.each { |bar| rows << [ "Completed swaps per month", bar.long_label, bar.count ] }
      most_wanted.each { |wanted| rows << [ "Most wanted (members wishing / copies on shelf)", wanted.title, "#{wanted.wanted_by} / #{wanted.on_shelf}" ] }
      unrequested_books.each do |book|
        rows << [ "On the shelf with no requests (days)", book.title, (period.now.to_date - self.class.listed_at(book).to_date).to_i ]
      end
      rows
    end
end
