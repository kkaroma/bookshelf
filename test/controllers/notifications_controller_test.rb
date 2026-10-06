require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    sign_in_as @alice
  end

  test "the bell shows the unread count" do
    get root_url
    assert_select "a.bell[aria-label=?]", "Notifications"
    assert_select ".bell-count", count: 0

    @bob.unfollow(@alice); @bob.follow(@alice)
    get root_url
    assert_select "a.bell[aria-label=?]", "Notifications (1 unread)"
    assert_select ".bell-count", "1"
  end

  test "the notifications page lists them, newest first" do
    @bob.unfollow(@alice); @bob.follow(@alice)
    books(:hobbit).comments.create!(user: @bob, body: "Lovely!")

    get notifications_url
    assert_select ".notification", 2
    assert_select ".notification.is-unread", 2
    assert_select ".notification:first-child .notification-text", /Bob Bookworm\s+commented on\s+The Hobbit/
    assert_select ".notification:last-child .notification-text", /Bob Bookworm\s+started following you/
  end

  test "opening a notification marks it read and goes to what it's about" do
    comment = books(:hobbit).comments.create!(user: @bob, body: "Lovely!")
    notification = @alice.notifications.first

    get notification_url(notification)
    assert_redirected_to book_path(books(:hobbit), anchor: "comment_#{comment.id}")
    assert notification.reload.read?
  end

  test "mark all as read" do
    @bob.unfollow(@alice); @bob.follow(@alice)
    patch mark_all_read_notifications_url
    assert_empty @alice.notifications.unread
  end

  test "you can't open someone else's notification" do
    other = Notification.notify(@bob, "new_follower", about: follows(:bob_follows_alice), actor: @alice)
    get notification_url(other)
    assert_response :not_found
  end

  test "empty state" do
    get notifications_url
    assert_select ".empty-state h2", "Nothing yet"
  end
end
