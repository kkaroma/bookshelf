# Puts a book on the exchange shelf (create) or takes it off (destroy).
# Lives at /books/:book_id/exchange_listing.
class Books::ExchangeListingsController < ApplicationController
  before_action :set_book
  before_action :require_editor

  def create
    @book.update!(available_for_exchange: true)
    redirect_to @book, notice: "“#{@book.title}” is now on the Exchange shelf."
  end

  def destroy
    @book.update!(available_for_exchange: false)
    redirect_to @book, notice: "“#{@book.title}” was removed from the Exchange shelf.", status: :see_other
  end

  private
    def set_book
      @book = Book.find(params.expect(:book_id))
    end

    def require_editor
      unless @book.editable_by?(Current.user)
        redirect_to @book, alert: "Only the person who added this book can offer it for exchange."
      end
    end
end
