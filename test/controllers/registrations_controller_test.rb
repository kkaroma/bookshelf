require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new shows the sign up form" do
    get new_registration_path
    assert_response :success
    assert_select "h1", "Create your account"
  end

  test "new redirects home when already signed in" do
    sign_in_as users(:one)
    get new_registration_path
    assert_redirected_to root_path
  end

  test "create with valid details makes an account and signs in" do
    assert_difference("User.count") do
      post registration_path, params: { user: {
        name: "Carol", email_address: "carol@example.com",
        password: "secret-password", password_confirmation: "secret-password"
      } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?

    follow_redirect!
    assert_select ".nav-user", /Carol/
  end

  test "cannot make yourself an admin when signing up" do
    post registration_path, params: { user: {
      name: "Mallory", email_address: "mallory@example.com",
      password: "secret-password", password_confirmation: "secret-password",
      role: "admin"
    } }

    assert User.find_by(email_address: "mallory@example.com").member?
  end

  test "create with invalid details shows errors" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: {
        name: "", email_address: "carol@example.com",
        password: "secret-password", password_confirmation: "secret-password"
      } }
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /Name can't be blank/
  end

  test "create with an email that is already taken" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: {
        name: "Copycat", email_address: users(:one).email_address,
        password: "secret-password", password_confirmation: "secret-password"
      } }
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /Email address has already been taken/
  end
end
