# All the numbers on the admin Reports page, worked out in one place.
# Every method only reads data; nothing here changes anything.
class AdminReport
  WEEKS = 8
  STALE_AFTER = 7.days
  TOP = 5

  Week = Data.define(:starts_on, :count)

  def initialize(now: Time.current)
    @now = now
  end

  attr_reader :now

  # --- 1. Overview ---

  def members_count        = User.count
  def members_this_month   = User.where(created_at: now.beginning_of_month..).count
  def books_count          = Book.count
  def books_with_cover     = Book.joins(:cover_attachment).count
  def books_with_isbn      = Book.where.not(isbn: nil).count
  def reviews_count        = Book.where.not(review: nil).count
  def comments_count       = Comment.count
  def ratings_count        = Rating.count
  def exchange_shelf_count = Book.for_exchange.count

  # { "pending" => 2, "accepted" => 1, "declined" => 0, "cancelled" => 0 }
  def requests_by_status
    counts = ExchangeRequest.group(:status).count
    ExchangeRequest.statuses.keys.index_with { |status| counts.fetch(status, 0) }
  end

  def percent(part, whole)
    whole.zero? ? 0 : (100.0 * part / whole).round
  end

  # --- 2. Activity over time ---

  def new_members_by_week = weekly(User)
  def new_books_by_week   = weekly(Book)

  # --- 3. Popular and active ---

  # Needs at least 2 ratings, so a single 5-star vote can't top the list.
  def top_rated_books
    Book.where(ratings_count: 2..).includes(:user)
        .order(average_rating: :desc, ratings_count: :desc).limit(TOP)
  end

  def most_requested_books
    Book.joins(:exchange_requests).includes(:user)
        .select("books.*, COUNT(exchange_requests.id) AS requests_total")
        .group("books.id").order("requests_total DESC", "books.title").limit(TOP)
  end

  # Activity = books added + comments written + ratings given.
  def most_active_members
    # The totals are worked out in an inner query first, because PostgreSQL
    # can't sort by a sum of columns calculated in the same SELECT.
    with_totals = User.select(<<~SQL)
      users.*,
      (SELECT COUNT(*) FROM comments WHERE comments.user_id = users.id) AS comments_total,
      (SELECT COUNT(*) FROM ratings  WHERE ratings.user_id  = users.id) AS ratings_total
    SQL

    User.from(with_totals, :users)
        .order(Arel.sql("users.books_count + users.comments_total + users.ratings_total DESC"), :name)
        .limit(TOP)
        .select { |user| user.books_count + user.comments_total + user.ratings_total > 0 }
  end

  # --- 4. Needs attention ---

  def stale_requests
    ExchangeRequest.pending.where(created_at: ...(now - STALE_AFTER))
                   .includes(:requester, book: :user).order(:created_at)
  end

  def recent_comments(limit: 10)
    Comment.includes(:user, :book).order(created_at: :desc).limit(limit)
  end

  def books_missing_details(limit: 10)
    books_missing_details_scope.includes(:user).with_attached_cover.order(:title).limit(limit)
  end

  def books_missing_details_count
    books_missing_details_scope.count
  end

  private
    # New records per week for the last WEEKS weeks (weeks start on Monday),
    # oldest first, including weeks with zero.
    def weekly(model)
      first_week = (now - (WEEKS - 1).weeks).beginning_of_week
      counts = model.where(created_at: first_week..now).pluck(:created_at)
                    .map { |time| time.in_time_zone.beginning_of_week.to_date }.tally

      Array.new(WEEKS) do |i|
        starts_on = (first_week + i.weeks).to_date
        Week.new(starts_on:, count: counts.fetch(starts_on, 0))
      end
    end

    def books_missing_details_scope
      without_cover = Book.left_joins(:cover_attachment)
      without_cover.where(active_storage_attachments: { id: nil }).or(without_cover.where(isbn: nil))
    end
end
