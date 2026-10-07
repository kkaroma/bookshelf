require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "new shows the sign up form with the spam traps" do
    get new_registration_path
    assert_response :success
    assert_select "h1", "Create your account"
    assert_select "input[type=hidden][name=form_started]"
    assert_select ".hp-field input[name=website][tabindex='-1']"
  end

  test "new redirects home when already signed in" do
    sign_in_as users(:one)
    get new_registration_path
    assert_redirected_to root_path
  end

  test "create with valid details makes an account and signs in" do
    assert_difference("User.count") do
      sign_up name: "Carol", email_address: "carol@example.com"
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?

    follow_redirect!
    assert_select ".nav-user", /Carol/
    assert_select ".flash-notice", /emailed a link to carol@example.com/
  end

  test "a new account starts unconfirmed and gets a confirmation email" do
    assert_enqueued_email_with AccountMailer, :email_confirmation, params: nil, args: ->(args) { args.first.email_address == "carol@example.com" } do
      sign_up name: "Carol", email_address: "carol@example.com"
    end

    assert_not User.find_by(email_address: "carol@example.com").email_confirmed?
    follow_redirect!
    assert_select ".confirm-banner", /Please confirm your email address/
  end

  test "cannot make yourself an admin when signing up" do
    sign_up name: "Mallory", email_address: "mallory@example.com", role: "admin"
    assert User.find_by(email_address: "mallory@example.com").member?
  end

  test "create with invalid details shows errors" do
    assert_no_difference("User.count") do
      sign_up name: "", email_address: "carol@example.com"
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /Name can't be blank/
  end

  test "create with an email that is already taken" do
    assert_no_difference("User.count") do
      sign_up name: "Copycat", email_address: users(:one).email_address
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /Email address has already been taken/
  end

  # --- Spam protection ---

  test "a filled-in honeypot field means a robot: no account" do
    assert_no_difference("User.count") do
      sign_up({ name: "Bot", email_address: "bot@example.com" }, website: "https://spam.example")
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /couldn't create your account/
  end

  test "a missing or forged form timer means no account" do
    assert_no_difference("User.count") do
      sign_up({ name: "Bot", email_address: "bot@example.com" }, form_started: "12345")
    end
    assert_select ".form-errors", /form expired/
  end

  test "a form sent too quickly is refused, then works when sent again after a moment" do
    RegistrationsController.minimum_fill_time = 3.seconds

    assert_no_difference("User.count") do
      sign_up({ name: "Quick", email_address: "quick@example.com" }, form_started: RegistrationsController.form_started_token)
    end
    assert_select ".form-errors", /That was quick/

    assert_difference("User.count") do
      sign_up({ name: "Quick", email_address: "quick@example.com" }, form_started: RegistrationsController.form_started_token(5.seconds.ago))
    end
  ensure
    RegistrationsController.minimum_fill_time = 0.seconds
  end

  private
    def sign_up(user, extra = {})
      post registration_path, params: {
        user: { password: "secret-password", password_confirmation: "secret-password" }.merge(user),
        form_started: RegistrationsController.form_started_token
      }.merge(extra)
    end
end
