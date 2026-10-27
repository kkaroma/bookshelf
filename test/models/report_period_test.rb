require "test_helper"

class ReportPeriodTest < ActiveSupport::TestCase
  test "defaults to the last 3 months, ignoring unknown choices" do
    assert_equal "3m", ReportPeriod.new(nil).key
    assert_equal "3m", ReportPeriod.new("forever").key
    assert_equal "Last 3 months", ReportPeriod.new(nil).label
  end

  test "each choice covers the right dates" do
    now = Time.zone.local(2026, 10, 28, 12)
    assert_equal now - 3.months, ReportPeriod.new("3m", now:).range.begin
    assert_equal now - 12.months, ReportPeriod.new("12m", now:).range.begin
    assert_equal Time.zone.local(2026, 1, 1), ReportPeriod.new("year", now:).range.begin
    assert_nil ReportPeriod.new("all", now:).range.begin
  end
end
