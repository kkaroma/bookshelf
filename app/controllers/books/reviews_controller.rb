# Lets a book's owner write or change their review without opening the
# full "Edit book" form. Lives at /books/:book_id/review.
class Books::ReviewsController < ApplicationController
  before_action :set_book
  before_action :require_editor

  def edit
  end

  def update
    if @book.update(review_params)
      redirect_to @book, notice: "Your review was saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_book
      @book = Book.find(params.expect(:book_id))
    end

    def require_editor
      unless @book.editable_by?(Current.user)
        redirect_to @book, alert: "Only the person who added this book can review it."
      end
    end

    # Only the review can be changed here, nothing else about the book.
    def review_params
      params.expect(book: [ :review ])
    end
end
