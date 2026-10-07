# /admin/reports - site statistics for admins. Read-only.
# /admin/reports.csv downloads the same numbers for Excel or Google Sheets.
class Admin::ReportsController < Admin::BaseController
  def show
    @report = AdminReport.new

    respond_to do |format|
      format.html
      format.csv do
        send_data @report.to_csv, type: "text/csv; charset=utf-8",
                  filename: "bookshelf-report-#{@report.now.to_date.iso8601}.csv"
      end
    end
  end
end
