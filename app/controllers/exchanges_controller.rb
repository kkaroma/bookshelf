# The Exchange shelf: every book members are willing to swap.
class ExchangesController < ApplicationController
  def index
    books = Book.for_exchange.with_attached_cover.includes(:user).order(updated_at: :desc)
    @pagination = Pagination.new(books, page: params[:page], per_page: 24)
    @books = @pagination.records
    @my_count = Book.for_exchange.where(user: Current.user).count
  end
end
