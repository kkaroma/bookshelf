require "test_helper"

class Admin::SwapsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "shows the swap numbers, charts and supply and demand" do
    WishlistItem.create!(user: users(:one), title: "Middlemarch")
    get admin_swaps_url

    assert_response :success
    assert_select ".tabs a.active", "Swaps"
    assert_select ".period-choice.active", "Last 3 months"
    assert_select ".stat-tile", /Requests made\s+1/
    assert_select ".stat-tile", /Waiting for an answer now\s+1/
    assert_select "#requests_chart_title", "Requests per month"
    assert_select "figure[aria-labelledby=completed_chart_title] .chart-col", 12
    assert_select "#most_wanted li", /Middlemarch.*Wanted by 1 member.*none on the shelf/m
    assert_select "#unrequested", /Every book on the shelf has had a request/
  end

  test "the period can be changed" do
    get admin_swaps_url(period: "all")
    assert_select ".period-choice.active", "All time"
    assert_select "#swap_overview_title", /all time/
    assert_select "a[href=?]", admin_swaps_path(period: "all", format: :csv), "Download CSV"
  end

  test "downloads as CSV" do
    get admin_swaps_url(period: "12m", format: :csv)
    assert_equal "text/csv", response.media_type
    assert_match(/filename="bookshelf-swaps-12m-/, response.headers["Content-Disposition"])
    assert_includes CSV.parse(response.body), [ "Report", "Period", "Last 12 months" ]
  end

  test "members get page not found" do
    sign_out
    sign_in_as users(:one)
    get admin_swaps_url
    assert_response :not_found
  end
end
