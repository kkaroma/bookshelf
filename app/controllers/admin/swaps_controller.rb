# /admin/swaps - how swapping is going, and supply versus demand.
class Admin::SwapsController < Admin::BaseController
  def show
    @report = SwapReport.new(period: ReportPeriod.new(params[:period]))

    respond_to do |format|
      format.html
      format.csv do
        send_data @report.to_csv, type: "text/csv; charset=utf-8",
                  filename: "bookshelf-swaps-#{@report.period.key}-#{Date.current.iso8601}.csv"
      end
    end
  end
end
