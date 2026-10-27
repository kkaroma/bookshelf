# /admin/journey - of the members who joined, how far they got.
class Admin::JourneysController < Admin::BaseController
  def show
    @journey = MemberJourney.new(period: ReportPeriod.new(params[:period]))

    respond_to do |format|
      format.html
      format.csv do
        send_data @journey.to_csv, type: "text/csv; charset=utf-8",
                  filename: "bookshelf-member-journey-#{@journey.period.key}-#{Date.current.iso8601}.csv"
      end
    end
  end
end
