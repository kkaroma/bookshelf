class Book < ApplicationRecord
  belongs_to :user

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

  # The owner can change their own book; admins can change any book.
  def editable_by?(someone)
    owned_by?(someone) || someone&.admin? || false
  end
end
