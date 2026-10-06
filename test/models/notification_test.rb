require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)  # owns The Hobbit
    @bob   = users(:two)  # owns Dune (on the Exchange shelf)
    @admin = users(:admin)
  end

  test "notify creates a notification about something" do
    follow = follows(:bob_follows_alice)
    notification = Notification.notify(@alice, "new_follower", about: follow, actor: @bob)

    assert_equal @alice, notification.recipient
    assert_equal follow, notification.notifiable
    assert_not notification.read?
  end

  test "nobody is notified about their own actions" do
    assert_nil Notification.notify(@alice, "new_follower", about: follows(:bob_follows_alice), actor: @alice)
  end

  test "mark_read! and the unread scope" do
    notification = Notification.notify(@alice, "new_follower", about: follows(:bob_follows_alice), actor: @bob)
    assert_includes @alice.notifications.unread, notification
    notification.mark_read!
    assert_not_includes @alice.notifications.unread, notification
  end

  # --- Events create notifications (the bell) as well as emails ---

  test "following someone notifies them" do
    assert_difference("@bob.notifications.count") { @alice.follow(@bob) }
    assert_equal "new_follower", @bob.notifications.first.kind
  end

  test "a comment notifies the owner; a reply also notifies the person replied to" do
    assert_difference("@alice.notifications.count") do
      books(:hobbit).comments.create!(user: @bob, body: "Lovely!")
    end
    assert_equal "new_comment", @alice.notifications.first.kind

    books(:hobbit).comments.create!(user: @admin, parent: comments(:bob_on_hobbit), body: "Agreed")
    assert_equal "new_reply", @bob.notifications.first.kind
  end

  test "exchange requests notify the owner, and answers notify the requester" do
    request = ExchangeRequest.create!(requester: @alice, book: books(:dune))
    assert_equal "exchange_request_received", @bob.notifications.first.kind

    request.accept!
    assert_equal "exchange_request_accepted", @alice.notifications.first.kind
    assert_equal "exchange_request_declined", @admin.notifications.first.kind # the other request was declined automatically
  end

  test "the bell is always notified, even when that email is switched off" do
    @bob.update!(notify_followers: false)
    assert_difference("@bob.notifications.count") { @alice.follow(@bob) }
  end

  test "notifications are deleted with what they're about" do
    @alice.follow(@bob)
    assert_difference("Notification.count", -1) { @alice.unfollow(@bob) }
  end

  test "deleting someone keeps others' notifications but forgets who did it" do
    notification = Notification.notify(@bob, "new_follower", about: follows(:bob_follows_alice), actor: @admin)
    @admin.destroy
    assert_nil notification.reload.actor
  end
end
