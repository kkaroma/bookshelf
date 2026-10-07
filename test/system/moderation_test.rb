require "application_system_test_case"

class ModerationTest < ApplicationSystemTestCase
  test "a member reports a comment, an admin removes it and suspends the author" do
    comment = comments(:bob_on_hobbit)

    # Alice reports Bob's comment on her book.
    sign_in_as users(:one)
    visit book_path(books(:hobbit))
    within("#comment_#{comment.id}") { click_on "Report" }
    assert_selector "h1", text: "Report a comment"
    choose "Rude, hateful or offensive"
    fill_in "Anything else the admins should know?", with: "Not kind at all"
    click_on "Send report"
    assert_text "Thanks for letting us know"
    click_on "Sign out"

    # The admin sees it waiting, and removes it.
    sign_in_as users(:admin)
    within(".nav-main") { assert_selector "a .nav-count", text: "1" }
    within(".nav-main") { click_on "Admin" }
    assert_selector ".tabs a.active", text: "Statistics"
    within(".tabs") { click_on "Reported content" }
    assert_text "Not kind at all"
    accept_confirm { click_on "Remove comment" }
    assert_text "The comment was removed."
    assert_text "Nothing to review"

    # ...then suspends Bob from the Members tab.
    within(".tabs") { click_on "Members" }
    within("#user_#{users(:two).id}") do
      accept_confirm { click_on "Suspend" }
    end
    assert_text "Bob Bookworm is suspended"
    within("#user_#{users(:two).id}") { assert_selector ".badge", text: /suspended/i }
    click_on "Sign out"

    # Bob can't sign in any more.
    visit new_session_path
    fill_in "Email address", with: users(:two).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "This account has been suspended"
  end
end
