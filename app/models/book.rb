class Book < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy

  # A review of only spaces is treated as "no review".
  normalizes :review, with: ->(review) { review.strip.presence }

  validates :title, :author, presence: true
  validates :subtitle, length: { maximum: 200 }
  validates :published_year,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true

  def owned_by?(someone)
    someone.present? && user_id == someone.id
  end

  # Anyone signed in can rate a book, except the person who added it.
  def rateable_by?(someone)
    someone.present? && !owned_by?(someone)
  end

  # Recalculates the cached ratings_count and average_rating columns.
  # The database does the maths (COUNT and AVG), not Ruby.
  def refresh_rating_stats!
    update_columns(ratings_count: ratings.count, average_rating: ratings.average(:score)&.round(1))
  end

  # The owner can change their own book; admins can change any book.
  def editable_by?(someone)
    owned_by?(someone) || someone&.admin? || false
  end
end
