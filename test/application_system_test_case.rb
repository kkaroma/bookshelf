require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  # Signs in through the real sign-in form, like a person would.
  def sign_in_as(user, password: "password")
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: password
    click_button "Sign in"
    assert_text "Signed in as #{user.name}"
  end
end
