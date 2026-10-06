# The Exchange shelf: every book members are willing to swap.
class ExchangesController < ApplicationController
  def index
    @my_city = Current.user.city
    @near_only = @my_city.present? && params[:near] == "1"

    books = Book.for_exchange.with_attached_cover.includes(:user).references(:user)
    if @my_city
      same_town = ActiveRecord::Base.sanitize_sql_array([ "LOWER(users.city) = ?", @my_city.downcase ])
      books = books.where(same_town) if @near_only
      # Books from my own town first, then everything else; newest within each.
      books = books.order(Arel.sql("CASE WHEN #{same_town} THEN 0 ELSE 1 END"))
    end
    books = books.order(updated_at: :desc)
    @pagination = Pagination.new(books, page: params[:page], per_page: 24)
    @books = @pagination.records
    @my_count = Book.for_exchange.where(user: Current.user).count
  end
end
