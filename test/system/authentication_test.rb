require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "signing up, signing out and signing back in" do
    visit root_path
    assert_text "Keep track of the books you own"

    click_on "Create your free account", match: :first
    fill_in "Name", with: "Carol"
    fill_in "Email address", with: "carol@example.com"
    fill_in "Password", with: "secret-password"
    fill_in "Confirm password", with: "secret-password"
    click_on "Create account"

    assert_text "Welcome to Bookshelf, Carol!"
    assert_selector ".nav-user-name", text: "Carol"
    # A new member lands on Home with the getting-started checklist
    assert_selector "h1", text: "Welcome back, Carol"
    assert_text "Getting started"
    assert_text "0 of 5 done"

    click_on "Sign out"
    assert_text "You have been signed out."

    fill_in "Email address", with: "carol@example.com"
    fill_in "Password", with: "secret-password"
    click_button "Sign in"
    assert_text "Welcome back, Carol!"
  end

  test "a new member confirms their email address from the link" do
    visit new_registration_path
    fill_in "Name", with: "Carol"
    fill_in "Email address", with: "carol@example.com"
    fill_in "Password", with: "secret-password"
    fill_in "Confirm password", with: "secret-password"
    click_on "Create account"

    assert_selector ".confirm-banner", text: "Please confirm your email address"
    click_on "Send the link again"
    assert_text "We've emailed a new confirmation link to carol@example.com"

    # Open the link from the email.
    visit email_confirmation_path(token: User.find_by!(email_address: "carol@example.com").generate_token_for(:email_confirmation))
    assert_text "Thanks, your email address is confirmed."
    assert_no_selector ".confirm-banner"
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
