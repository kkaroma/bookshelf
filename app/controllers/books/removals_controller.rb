# "I no longer have it" (POST) moves a book to the owner's "Books I've had",
# keeping its review, comments and ratings; DELETE puts it back on the shelf.
# Lives at /books/:book_id/removal. Only the owner can do this.
class Books::RemovalsController < ApplicationController
  before_action :set_book

  def create
    @book.give_away!
    redirect_to @book, notice: "“#{@book.title}” moved to Books I've had. Its review and comments stay on your profile."
  end

  def destroy
    if @book.successor_id
      redirect_to @book, alert: "This book went to someone in a swap, so it can't come back to your shelf."
    else
      @book.put_back_on_shelf!
      redirect_to @book, notice: "“#{@book.title}” is back on your shelf.", status: :see_other
    end
  end

  private
    def set_book
      @book = Current.user.books.find(params.expect(:book_id))
    end
end
