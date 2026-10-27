require "test_helper"

class ReportBarTest < ActiveSupport::TestCase
  test "monthly makes twelve months ending with the given one, counting dates" do
    dates = [ Date.new(2026, 10, 3), Date.new(2026, 10, 28), Date.new(2026, 1, 9), Date.new(2025, 6, 1) ]
    bars = ReportBar.monthly(dates, last_month: Date.new(2026, 10, 15))

    assert_equal 12, bars.size
    assert_equal "November 2025", bars.first.long_label
    assert_equal "Oct", bars.last.short_label
    assert_equal 2, bars.last.count
    assert_equal 1, bars.find { |bar| bar.long_label == "January 2026" }.count
    assert_equal 3, bars.sum(&:count) # June 2025 is outside the twelve months
  end
end
