require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ] do |options|
    # Chrome's password manager can pop up an invisible "password found in a
    # data breach" warning after signing in with a test password, which then
    # swallows the next clicks. Turn it off for tests.
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordManagerOnboarding")
  end

  # Give the browser a little longer than Capybara's 2-second default before
  # an assertion gives up, so a slow moment on the machine doesn't fail a test.
  Capybara.default_max_wait_time = 5

  # Let tests find buttons by their accessible name (aria-label), e.g. the
  # star buttons whose visible text is just "★".
  Capybara.enable_aria_label = true

  # Signs in through the real sign-in form, like a person would.
  def sign_in_as(user, password: "password")
    visit new_session_path
    # Wait until the sign-in page has fully loaded before typing into it.
    assert_selector "h1", text: "Welcome back"

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: password
    click_button "Sign in"
    assert_text "Signed in as #{user.name}"
  end
end
