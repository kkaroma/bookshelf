require "csv"

# Shared by the admin reports that download as a spreadsheet: each report
# lists [section, item, value] rows in `csv_rows`, and this turns them into a
# CSV file with a header row.
module ReportCsv
  def to_csv
    CSV.generate do |csv|
      csv << [ "Section", "Item", "Value" ]
      csv_rows.each { |section, item, value| csv << [ section, spreadsheet_safe(item), value ] }
    end
  end

  private
    # Spreadsheets run anything starting with = + - or @ as a formula, so a
    # book titled "=HYPERLINK(...)" could do harm. A leading ' makes it text.
    def spreadsheet_safe(text)
      text = text.to_s
      text.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text
    end
end
