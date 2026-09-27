class Rating < ApplicationRecord
  SCORES = 1..5

  belongs_to :user
  belongs_to :book

  validates :score, presence: true, inclusion: { in: SCORES, message: "must be between 1 and 5" }
  validates :user_id, uniqueness: { scope: :book_id, message: "has already rated this book" }
  validate :not_rating_own_book

  # Keep the book's cached average and count up to date.
  after_save    :refresh_book_stats
  after_destroy :refresh_book_stats

  private
    def not_rating_own_book
      errors.add(:base, "You can't rate your own book") if book && user_id == book.user_id
    end

    def refresh_book_stats
      book.refresh_rating_stats!
    end
end
