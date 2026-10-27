# One column in a bar chart (shared/_bar_chart): "Oct" on the axis,
# "October 2026" in the tooltip and table, and its value.
ReportBar = Data.define(:short_label, :long_label, :count) do
  # Twelve monthly columns ending with `last_month`, counting the dates given.
  def self.monthly(dates, last_month: Date.current, months: 12)
    counts = dates.map { |date| date.to_date.beginning_of_month }.tally
    first = last_month.to_date.beginning_of_month << (months - 1)
    Array.new(months) do |i|
      month = first >> i
      new(short_label: month.strftime("%b"), long_label: month.strftime("%B %Y"), count: counts.fetch(month, 0))
    end
  end
end
