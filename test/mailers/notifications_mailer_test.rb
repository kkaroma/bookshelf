require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "exchange request received" do
    request = exchange_requests(:admin_wants_dune) # Ada asked Bob for Dune
    email = NotificationsMailer.exchange_request_received(request)

    assert_equal [ users(:two).email_address ], email.to
    assert_equal "Ada Admin wants to swap for “Dune”", email.subject
    assert_match "always wanted to read this one", email.html_part.body.to_s
    assert_match "/exchange_requests", email.text_part.body.to_s
    assert_match "/settings/notifications/edit", email.text_part.body.to_s
  end

  test "exchange request accepted shows the owner's email" do
    request = exchange_requests(:admin_wants_dune)
    request.status = :accepted
    email = NotificationsMailer.exchange_request_answered(request)

    assert_equal [ users(:admin).email_address ], email.to
    assert_equal "Your request for “Dune” was accepted", email.subject
    assert_match users(:two).email_address, email.text_part.body.to_s
  end

  test "exchange request declined" do
    request = exchange_requests(:admin_wants_dune)
    request.status = :declined
    email = NotificationsMailer.exchange_request_answered(request)

    assert_equal "Your request for “Dune” was declined", email.subject
    assert_no_match users(:two).email_address, email.text_part.body.to_s
  end

  test "new comment on your book" do
    comment = comments(:bob_on_hobbit)
    email = NotificationsMailer.new_comment(comment, users(:one))

    assert_equal [ users(:one).email_address ], email.to
    assert_equal "Bob Bookworm commented on “The Hobbit”", email.subject
    assert_match "riddles chapter", email.text_part.body.to_s
  end

  test "reply to your comment" do
    reply = comments(:alice_reply_to_bob) # Alice replied to Bob
    email = NotificationsMailer.new_comment(reply, users(:two))

    assert_equal "Alice Reader replied to your comment on “The Hobbit”", email.subject
  end

  test "new follower" do
    email = NotificationsMailer.new_follower(follows(:bob_follows_alice))

    assert_equal [ users(:one).email_address ], email.to
    assert_equal "Bob Bookworm is now following you on Bookshelf", email.subject
    assert_match "/users/#{users(:two).id}", email.text_part.body.to_s
  end
end
