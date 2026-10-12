require "test_helper"

# Pages only exist as HTML. Asking for them as JSON or XML (bots, link
# previews) gets "406 Not Acceptable" instead of crashing.
class UnsupportedFormatsTest < ActionDispatch::IntegrationTest
  test "the home page as JSON is not acceptable, for visitors and members" do
    get root_url, headers: { "Accept" => "application/json" }
    assert_response :not_acceptable

    sign_in_as users(:one)
    get root_url, headers: { "Accept" => "application/json" }
    assert_response :not_acceptable
  end

  test "other pages as JSON or XML are not acceptable either" do
    sign_in_as users(:one)
    get user_url(users(:two)), headers: { "Accept" => "application/json" }
    assert_response :not_acceptable

    get users_url(format: :xml)
    assert_response :not_acceptable
  end

  test "normal browser requests still work" do
    get root_url, headers: { "Accept" => "text/html,application/xhtml+xml,*/*;q=0.8" }
    assert_response :success

    get root_url, headers: { "Accept" => "*/*" }
    assert_response :success
  end

  test "it isn't reported as an error" do
    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error }
    Rails.error.subscribe(subscriber)

    get root_url, headers: { "Accept" => "application/json" }
    assert_empty reported
  ensure
    Rails.error.unsubscribe(subscriber)
  end
end
