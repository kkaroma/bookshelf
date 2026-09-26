class Book < ApplicationRecord
  validates :title, :author, presence: true
  validates :published_year,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true
end
