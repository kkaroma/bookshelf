# Splits a long list into pages.
#
#   pagination = Pagination.new(Book.order(:title), page: params[:page], per_page: 24)
#   pagination.records      # just this page's books
#   pagination.total_count  # how many books there are altogether
#
# A missing or out-of-range page number goes to the nearest real page.
class Pagination
  attr_reader :page, :per_page, :total_count

  def initialize(scope, page:, per_page:)
    @scope = scope
    @per_page = per_page
    # Counting ignores ORDER BY (PostgreSQL won't COUNT an ordered query).
    @total_count = scope.unscope(:order).count
    @page = page.to_i.clamp(1, total_pages)
  end

  def records
    @scope.limit(per_page).offset((page - 1) * per_page)
  end

  def total_pages
    [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  def multiple_pages?
    total_pages > 1
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if page < total_pages
  end

  # e.g. "25–48 of 112"
  def first_item = total_count.zero? ? 0 : (page - 1) * per_page + 1
  def last_item  = [ page * per_page, total_count ].min
end
