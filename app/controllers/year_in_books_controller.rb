# /year-in-books and /year-in-books/2025: your own year in books.
# Always the signed-in member's own data; nobody else's can be shown.
class YearInBooksController < ApplicationController
  def show
    year = params[:year]&.to_i || Date.current.year
    return head(:not_found) unless year.between?(2000, Date.current.year)

    @year_in_books = YearInBooks.new(Current.user, year)
  end
end
