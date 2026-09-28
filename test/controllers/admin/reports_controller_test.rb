require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  test "admins can see the reports" do
    sign_in_as users(:admin)
    get admin_reports_url

    assert_response :success
    assert_select "h1", "Reports"
    assert_select "#overview_title", "Overview"
    assert_select ".stat-tile", 7
    assert_select ".stat-tile", /Members\s+3/
    assert_select ".stat-tile", /Exchange requests\s+1\s+1 pending/
  end

  test "weekly charts have 8 labelled columns and a table view" do
    sign_in_as users(:admin)
    get admin_reports_url

    assert_select "#members_chart_title", "New members per week"
    assert_select ".chart", 2
    assert_select "figure[aria-labelledby=books_chart_title] .chart-col", 8
    assert_select ".chart-col[aria-label=?]",
                  "Week of #{Time.current.beginning_of_week.strftime("%-d %b")}: 2 new books"
    assert_select ".chart-table table", 2
  end

  test "lists popular books, active members and things needing attention" do
    sign_in_as users(:admin)
    get admin_reports_url

    assert_select "#top_rated li", /The Hobbit/
    assert_select "#most_requested li", /Dune\s+1 request/
    assert_select "#most_active li", 3
    assert_select "#stale_requests", /Nothing waiting that long/
    assert_select "#recent_comments li", 3
    assert_select "#missing_details a[href=?]", edit_book_path(books(:dune))
  end

  test "members get page not found" do
    sign_in_as users(:one)
    get admin_reports_url
    assert_response :not_found
    assert_no_match "Overview", response.body
  end

  test "visitors are sent to sign in" do
    get admin_reports_url
    assert_redirected_to new_session_url
  end

  test "only admins see the Reports link" do
    sign_in_as users(:one)
    get root_url
    assert_select ".nav-main a", text: "Reports", count: 0

    sign_out
    sign_in_as users(:admin)
    get root_url
    assert_select ".nav-main a[href=?]", admin_reports_path, text: "Reports"
  end
end
