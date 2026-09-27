require "test_helper"

class Users::FollowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob   = users(:two) # follows Alice
    sign_in_as @alice
  end

  test "follow someone" do
    assert_difference("Follow.count") do
      post user_follow_url(@bob)
    end

    assert @alice.following?(@bob)
    assert_equal 1, @bob.reload.followers_count
    assert_redirected_to user_url(@bob)
  end

  test "following returns you to the page you were on" do
    post user_follow_url(@bob), headers: { "Referer" => users_url }
    assert_redirected_to users_url
  end

  test "unfollow someone" do
    @alice.follow(@bob)

    assert_difference("Follow.count", -1) do
      delete user_follow_url(@bob)
    end
    assert_not @alice.reload.following?(@bob)
  end

  test "following twice does not create a duplicate" do
    post user_follow_url(@bob)
    assert_no_difference("Follow.count") { post user_follow_url(@bob) }
  end

  test "cannot follow yourself" do
    assert_no_difference("Follow.count") { post user_follow_url(@alice) }
    follow_redirect!
    assert_select ".flash-alert", /can't follow yourself/
  end

  test "the button switches between Follow and Unfollow" do
    get user_url(@bob)
    assert_select ".follow-box button", "Follow"

    post user_follow_url(@bob)
    get user_url(@bob)
    assert_select ".follow-box button", "Unfollow"
    assert_select ".follow-box .follow-count", "1 follower"
  end

  test "signed-out visitors cannot follow" do
    sign_out
    assert_no_difference("Follow.count") { post user_follow_url(@bob) }
    assert_redirected_to new_session_url
  end
end
