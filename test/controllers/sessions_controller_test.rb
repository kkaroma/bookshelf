require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "new redirects home when already signed in" do
    sign_in_as(@user)
    get new_session_path
    assert_redirected_to root_path
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "suspended members can't sign in" do
    users(:two).suspend!
    post session_path, params: { email_address: "two@example.com", password: "password" }

    assert_redirected_to new_session_path
    assert_match(/suspended/, flash[:alert])
    assert_nil cookies[:session_id].presence
  end

  test "a suspended member's old session no longer works" do
    sign_in_as users(:two)
    users(:two).update_columns(suspended_at: Time.current) # even if a session were left behind
    get books_url
    assert_redirected_to new_session_url
  end
end
