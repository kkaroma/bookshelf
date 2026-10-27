require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  test "two members message each other, then one blocks the other" do
    # Alice starts a conversation from Bob's profile.
    sign_in_as users(:one)
    visit user_path(users(:two))
    within(".profile-actions") { click_on "Message" }
    assert_selector "h1", text: "Bob Bookworm"
    assert_text "No messages yet"

    fill_in "Message Bob Bookworm", with: "Hi Bob! Is Dune still up for a swap?"
    click_on "Send"
    within("#direct_messages") { assert_selector ".message.is-mine", text: "Is Dune still up for a swap?" }
    assert_no_text "No messages yet"
    assert_field "Message Bob Bookworm", with: "" # the box is cleared for the next one
    click_on "Sign out"

    # Bob sees one unread message in the header and replies.
    sign_in_as users(:two)
    assert_selector "a.bell[aria-label='Messages (1 unread)']"
    find("a.bell[aria-label='Messages (1 unread)']").click
    assert_selector "h1", text: "Messages"
    within(".conversation-row.is-unread") { click_on "Alice Reader" }
    assert_selector ".message.is-theirs", text: "Is Dune still up for a swap?"
    fill_in "Message Alice Reader", with: "Yes! Saturday at the library?"
    click_on "Send"
    assert_selector ".message.is-mine", text: "Saturday at the library?"
    assert_no_selector "a.bell[aria-label^='Messages (']" # read now

    # ...then blocks her.
    accept_confirm { click_on "Block" }
    assert_text "You've blocked Alice Reader"
    assert_selector ".conversation-closed", text: "You've blocked Alice Reader"
    click_on "Sign out"

    # Alice can't send any more.
    sign_in_as users(:one)
    find("a.bell[aria-label='Messages (1 unread)']").click # Bob's reply
    click_on "Bob Bookworm"
    assert_selector ".conversation-closed", text: "You can't send messages to Bob Bookworm."
    assert_no_field "Message Bob Bookworm"
  end
end
