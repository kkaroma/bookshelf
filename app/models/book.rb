class Book < ApplicationRecord
  belongs_to :user

  validates :title, :author, presence: true
  validates :subtitle, length: { maximum: 200 }
  validates :published_year,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true

  def owned_by?(someone)
    someone.present? && user_id == someone.id
  end
end
