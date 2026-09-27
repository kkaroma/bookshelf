# The signed-in user's own rating of a book: PUT to rate or re-rate, DELETE to remove.
# Lives at /books/:book_id/rating (singular - you have at most one rating per book).
class Books::RatingsController < ApplicationController
  before_action :set_book

  def update
    # Update my existing rating, or start a new one if I haven't rated yet.
    rating = @book.ratings.find_or_initialize_by(user: Current.user)
    rating.score = params.expect(rating: [ :score ])[:score]

    if rating.save
      redirect_to @book, notice: "Thanks! You rated this book #{rating.score} out of 5."
    else
      redirect_to @book, alert: rating.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotUnique
    # Two clicks arrived at the same moment and both tried to create a rating.
    # The database's unique index stopped the second one; try again as an update.
    retry
  end

  def destroy
    @book.ratings.find_by(user: Current.user)&.destroy
    redirect_to @book, notice: "Your rating was removed.", status: :see_other
  end

  private
    def set_book
      @book = Book.find(params.expect(:book_id))
    end
end
