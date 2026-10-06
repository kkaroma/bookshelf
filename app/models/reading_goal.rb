# "Read 20 books in 2026". One goal per member per year; progress counts the
# member's books marked "Read" with a finish date in that year.
class ReadingGoal < ApplicationRecord
  belongs_to :user

  validates :year, numericality: { only_integer: true, in: 2000..2100 }, uniqueness: { scope: :user_id }
  validates :target, numericality: { only_integer: true, in: 1..1000, message: "must be between 1 and 1000 books" }

  def books_read
    user.books.read.where(finished_on: Date.new(year).all_year)
  end

  def progress
    @progress ||= books_read.count
  end

  def percent
    [ 100 * progress / target, 100 ].min
  end

  def reached?
    progress >= target
  end
end
