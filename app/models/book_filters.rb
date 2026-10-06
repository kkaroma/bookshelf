# The search, filter and sort choices for a list of books, read from the
# address bar (?q=…&genre=…&status=…&exchange=1&sort=…) and applied to a scope.
#
#   filters = BookFilters.new(params)
#   books = filters.apply(Book.all)
class BookFilters
  SORTS = {
    "title"  => "Title A–Z",
    "newest" => "Newest first",
    "rating" => "Highest rated",
    "year"   => "Publication year"
  }.freeze

  attr_reader :query, :genre, :status, :sort

  def initialize(params, allow_status: false)
    @query = params[:q].to_s.squish
    @genre = params[:genre].presence_in(Book::GENRES)
    @status = params[:status].presence_in(Book.reading_statuses.keys) if allow_status
    @exchange_only = params[:exchange] == "1"
    @sort = params[:sort].presence_in(SORTS.keys) || "title"
  end

  def exchange_only? = @exchange_only

  # Anything that narrows the list (sorting alone doesn't count).
  def filtering?
    query.present? || genre || status || exchange_only?
  end

  def apply(scope)
    scope = scope.search(query) if query.present?
    scope = scope.where(genre: genre) if genre
    scope = scope.where(reading_status: status) if status
    scope = scope.for_exchange if exchange_only?
    scope.order(*order_clause)
  end

  private
    def order_clause
      case sort
      when "newest" then [ { created_at: :desc } ]
      when "rating" then [ Arel.sql("books.average_rating DESC NULLS LAST"), { ratings_count: :desc }, :title ]
      when "year"   then [ Arel.sql("books.published_year DESC NULLS LAST"), :title ]
      else [ :title ]
      end
    end
end
