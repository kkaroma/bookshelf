require "application_system_test_case"

class PublicPagesTest < ApplicationSystemTestCase
  test "Alice makes her profile public and a visitor reads her review" do
    sign_in_as users(:one)
    within(".public-question") { click_on "Make my profile public" }
    assert_text "Your profile is public"

    visit book_path(books(:hobbit))
    assert_selector ".book-share", text: "Anyone with the link can read this page"
    click_on "Sign out"

    # A friend opens the link she shared - no account needed.
    visit book_path(books(:hobbit))
    assert_selector "h1", text: "The Hobbit"
    assert_selector ".book-review-text", text: "cosy adventure"
    assert_no_text comments(:bob_on_hobbit).body
    click_on "Alice Reader"
    assert_selector "h1", text: "Alice Reader"
    within(".join-card") { click_on "Create your free account" }
    assert_selector "h1", text: "Create your account"
  end
end
