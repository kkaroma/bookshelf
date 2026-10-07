require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  test "admins can see the reports" do
    sign_in_as users(:admin)
    get admin_reports_url

    assert_response :success
    assert_select "h1", "Admin"
    assert_select ".tabs a.active", "Statistics"
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

  test "only admins see the Admin link" do
    sign_in_as users(:one)
    get root_url
    assert_select ".nav-main a[href=?]", admin_reports_path, count: 0

    sign_out
    sign_in_as users(:admin)
    get root_url
    assert_select ".nav-main a[href=?]", admin_reports_path, text: "Admin"
  end

  test "the Admin link counts reported items waiting" do
    Flag.create!(reporter: users(:one), flaggable: books(:dune), reason: "spam")
    Flag.create!(reporter: users(:one), flaggable: comments(:bob_on_hobbit), reason: "offensive")
    sign_in_as users(:admin)
    get root_url
    assert_select ".nav-main a[href=?] .nav-count", admin_reports_path, "2"
  end

  # --- CSV download ---

  test "the reports page links to the CSV download" do
    sign_in_as users(:admin)
    get admin_reports_url
    assert_select "a[href=?]", admin_reports_path(format: :csv), "Download CSV"
  end

  test "the CSV has a row per number" do
    sign_in_as users(:admin)
    get admin_reports_url(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment; filename="bookshelf-report-#{Date.current.iso8601}\.csv"/, response.headers["Content-Disposition"])

    rows = CSV.parse(response.body)
    assert_equal [ "Section", "Item", "Value" ], rows.first
    assert_includes rows, [ "Overview", "Members", "3" ]
    assert_includes rows, [ "Exchange requests", "Pending", "1" ]
    assert_equal 8, rows.count { |row| row[0] == "New books per week" }
    assert_includes rows, [ "Most-requested books", "Dune", "1" ]
  end

  test "members can't download the CSV" do
    sign_in_as users(:one)
    get admin_reports_url(format: :csv)
    assert_response :not_found
  end
end
