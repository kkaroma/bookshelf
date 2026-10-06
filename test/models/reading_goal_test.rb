require "test_helper"

class ReadingGoalTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @goal = @alice.reading_goals.create!(year: 2026, target: 4)
  end

  def finish(title, on:)
    @alice.books.create!(title: title, author: "A", reading_status: "read", finished_on: on)
  end

  test "counts books marked Read that were finished in the goal's year" do
    finish "One", on: Date.new(2026, 1, 15)
    finish "Two", on: Date.new(2026, 9, 30)
    finish "Last year", on: Date.new(2025, 12, 31)
    @alice.books.create!(title: "Still reading", author: "A", reading_status: "reading", started_on: Date.new(2026, 2, 1))

    assert_equal 2, @goal.progress
    assert_equal 50, @goal.percent
    assert_not @goal.reached?
  end

  test "reaching the goal, and going past it" do
    5.times { |i| finish "Book #{i}", on: Date.new(2026, 3, 1) }
    assert @goal.reached?
    assert_equal 100, @goal.percent # never more than 100
  end

  test "one goal per member per year, with a sensible target" do
    assert_not @alice.reading_goals.new(year: 2026, target: 5).valid?
    assert @alice.reading_goals.new(year: 2027, target: 5).valid?
    assert_not @alice.reading_goals.new(year: 2028, target: 0).valid?
    assert_not @alice.reading_goals.new(year: 2028, target: 5000).valid?
  end

  test "reading_goal_for finds this year's goal" do
    travel_to Date.new(2026, 6, 1) do
      assert_equal @goal, @alice.reading_goal_for
      assert_nil @alice.reading_goal_for(2027)
    end
  end
end
