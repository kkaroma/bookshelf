# /admin/reports - site statistics for admins. Read-only.
class Admin::ReportsController < Admin::BaseController
  def show
    @report = AdminReport.new
  end
end
