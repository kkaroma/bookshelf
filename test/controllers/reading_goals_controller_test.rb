require "test_helper"

class ReadingGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    sign_in_as @alice
  end

  test "Home invites you to set a goal" do
    get root_url
    assert_select "#reading_goal h2", "Set a reading goal for #{Date.current.year}"
    assert_select "#reading_goal input[type=submit][value=?]", "Set goal"
  end

  test "set, change and remove this year's goal" do
    patch reading_goal_url, params: { reading_goal: { target: 20 } }
    assert_redirected_to root_path
    assert_equal 20, @alice.reading_goal_for.target

    patch reading_goal_url, params: { reading_goal: { target: 30 } }
    assert_equal 30, @alice.reading_goal_for.target
    assert_equal 1, @alice.reading_goals.count

    delete reading_goal_url
    assert_nil @alice.reading_goal_for
  end

  test "Home shows progress once a goal is set" do
    @alice.reading_goals.create!(year: Date.current.year, target: 2)
    books(:hobbit).update!(reading_status: "read", finished_on: Date.current)

    get root_url
    assert_select "#reading_goal h2", "Reading goal #{Date.current.year}"
    assert_select ".reading-goal-count", /1\s+of 2 books read/
    assert_select "#reading_goal [role=progressbar][aria-valuenow='1']"
  end

  test "a silly target is refused with a message" do
    patch reading_goal_url, params: { reading_goal: { target: 0 } }
    assert_nil @alice.reading_goal_for
    follow_redirect!
    assert_select ".flash-alert", /between 1 and 1000/
  end
end
