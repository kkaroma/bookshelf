# The time span an admin report covers, chosen with ?period=… :
# the last 3 months (default), the last 12 months, this year, or all time.
class ReportPeriod
  CHOICES = {
    "3m"   => "Last 3 months",
    "12m"  => "Last 12 months",
    "year" => "This year",
    "all"  => "All time"
  }.freeze

  attr_reader :key, :now

  def initialize(key, now: Time.current)
    @key = CHOICES.key?(key) ? key : "3m"
    @now = now
  end

  def label = CHOICES.fetch(key)

  # A range for `where(created_at: period.range)`.
  def range
    case key
    when "3m"   then (now - 3.months)..now
    when "12m"  then (now - 12.months)..now
    when "year" then now.beginning_of_year..now
    when "all"  then ..now
    end
  end
end
