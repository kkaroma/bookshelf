# The Exchange shelf: every book members are willing to swap.
class ExchangesController < ApplicationController
  def index
    @books = Book.for_exchange.includes(:user).order(updated_at: :desc)
    @my_count = @books.count { |book| book.owned_by?(Current.user) }
  end
end
