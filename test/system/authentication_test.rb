require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "signing up, signing out and signing back in" do
    visit root_path
    assert_current_path new_session_path

    click_on "Create an account"
    fill_in "Name", with: "Carol"
    fill_in "Email address", with: "carol@example.com"
    fill_in "Password", with: "secret-password"
    fill_in "Confirm password", with: "secret-password"
    click_on "Create account"

    assert_text "Welcome to Bookshelf, Carol!"
    assert_text "Signed in as Carol"

    click_on "Sign out"
    assert_text "You have been signed out."

    fill_in "Email address", with: "carol@example.com"
    fill_in "Password", with: "secret-password"
    click_button "Sign in"
    assert_text "Welcome back, Carol!"
  end

  test "sign up shows errors for bad details" do
    visit new_registration_path
    fill_in "Name", with: "Carol"
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "secret-password"
    fill_in "Confirm password", with: "different-password"
    click_on "Create account"

    assert_text "Email address has already been taken"
    assert_text "Password confirmation doesn't match Password"
  end
end
