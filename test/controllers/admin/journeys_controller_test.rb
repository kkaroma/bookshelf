require "test_helper"

class Admin::JourneysControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "shows each step with counts and percentages" do
    carol = User.create!(name: "Carol", email_address: "carol@example.com", password: "password123")
    carol.confirm_email!

    get admin_journey_url
    assert_response :success
    assert_select ".tabs a.active", "Member journey"
    assert_select "#journey_title", /4 members joined/ # the three fixture members + Carol
    assert_select ".funnel-step", 5
    assert_select "#step_joined .funnel-value", /4\s+100%/
    assert_select "#no_books li", /Carol/
  end

  test "an empty period says so" do
    User.update_all(created_at: 2.years.ago)
    get admin_journey_url(period: "year")
    assert_select ".funnel", 0
    assert_select "p", /Nobody joined in this period/
  end

  test "downloads as CSV" do
    get admin_journey_url(format: :csv)
    assert_equal "text/csv", response.media_type
    assert_includes CSV.parse(response.body), [ "Journey", "Signed up", "3" ]
  end

  test "members get page not found" do
    sign_out
    sign_in_as users(:one)
    get admin_journey_url
    assert_response :not_found
  end
end
