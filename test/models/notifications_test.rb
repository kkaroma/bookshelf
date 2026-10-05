require "test_helper"

# Which events send which emails, and that the on/off switches are respected.
class NotificationsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alice = users(:one)  # owns The Hobbit
    @bob   = users(:two)  # owns Dune (on the Exchange shelf)
    @admin = users(:admin)
  end

  # --- Exchange requests ---

  test "a new exchange request emails the book's owner" do
    assert_enqueued_email_with NotificationsMailer, :exchange_request_received, args: ->(args) { args.first.requester == @alice } do
      ExchangeRequest.create!(requester: @alice, book: books(:dune))
    end
  end

  test "no email when the owner switched exchange emails off" do
    @bob.update!(notify_exchange_requests: false)
    assert_no_enqueued_emails do
      ExchangeRequest.create!(requester: @alice, book: books(:dune))
    end
  end

  test "accepting or declining emails the requester; cancelling doesn't" do
    request = exchange_requests(:admin_wants_dune)
    assert_enqueued_email_with NotificationsMailer, :exchange_request_answered, args: [ request ] do
      request.accept!
    end

    books(:hobbit).update!(available_for_exchange: true)
    other = ExchangeRequest.create!(requester: @admin, book: books(:hobbit))
    assert_no_enqueued_emails { other.cancel! }
  end

  test "requests declined automatically still tell the requester" do
    request = exchange_requests(:admin_wants_dune)
    assert_enqueued_email_with NotificationsMailer, :exchange_request_answered, args: [ request ] do
      books(:dune).update!(available_for_exchange: false) # Bob takes Dune off the shelf
    end
  end

  # --- Comments ---

  test "a comment emails the book's owner" do
    assert_enqueued_emails 1 do
      books(:hobbit).comments.create!(user: @bob, body: "Lovely!")
    end
  end

  test "no email for commenting on your own book" do
    assert_no_enqueued_emails do
      books(:hobbit).comments.create!(user: @alice, body: "Thanks all")
    end
  end

  test "a reply emails the book's owner and the person replied to" do
    parent = comments(:bob_on_hobbit) # Bob's comment on Alice's book
    reply = Comment.new(user: @admin, book: books(:hobbit), parent: parent, body: "Agreed")
    assert_equal [ @alice, @bob ].sort_by(&:id), reply.people_to_notify.sort_by(&:id)

    assert_enqueued_emails 2 do
      reply.save!
    end
  end

  test "comment emails respect the switch" do
    @alice.update!(notify_comments: false)
    assert_no_enqueued_emails do
      books(:hobbit).comments.create!(user: @bob, body: "Lovely!")
    end
  end

  # --- Follows ---

  test "a new follower emails the person followed" do
    assert_enqueued_emails 1 do
      @alice.follow(@bob)
    end
  end

  test "follower emails respect the switch" do
    @bob.update!(notify_followers: false)
    assert_no_enqueued_emails { @alice.follow(@bob) }
  end
end
