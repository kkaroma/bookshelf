require "test_helper"

# Messages and completing swaps.
class SwapTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alice  = users(:one)   # owns The Hobbit
    @bob    = users(:two)   # owns Dune (on the Exchange shelf)
    @hobbit = books(:hobbit)
    @dune   = books(:dune)
    @request = ExchangeRequest.create!(requester: @alice, book: @dune, offered_book: @hobbit)
  end

  test "a request remembers the book's owner" do
    assert_equal @bob, @request.owner
    assert @request.participant?(@alice)
    assert @request.participant?(@bob)
    assert_not @request.participant?(users(:admin))
    assert_equal @bob, @request.other_party(@alice)
  end

  # --- Messages ---

  test "only the two people involved can send messages" do
    assert @request.messages.create(sender: @alice, body: "Hi!").persisted?
    assert_not @request.messages.new(sender: users(:admin), body: "Me too").valid?
    assert_not @request.messages.new(sender: @bob, body: "  ").valid?
  end

  test "a message notifies the other person; only the first unread one is emailed" do
    assert_enqueued_emails 1 do
      @request.messages.create!(sender: @alice, body: "Hi Bob!")
      @request.messages.create!(sender: @alice, body: "Are you free Saturday?")
    end
    assert_equal 2, @bob.notifications.where(kind: "new_message").count

    @bob.notifications.update_all(read_at: Time.current) # Bob reads them
    assert_enqueued_emails 1 do
      @request.messages.create!(sender: @alice, body: "Still there?")
    end
  end

  test "message emails respect the switch" do
    @request.owner.update!(notify_messages: false) # the request's own copy of Bob
    assert_no_enqueued_emails { @request.messages.create!(sender: @alice, body: "Hi") }
  end

  # --- Completing ---

  test "only accepted requests can be marked done" do
    assert_raises(ExchangeRequest::NotAccepted) { @request.complete!(by: @bob) }
  end

  test "completing a swap gives each person their own copy and keeps the givers' copies" do
    @hobbit.update!(review: "Alice's thoughts", reading_status: "read", finished_on: Date.current)
    comment = @hobbit.comments.create!(user: @bob, body: "Great review!")
    @hobbit.loans.create!(borrower_name: "Sam", lent_on: Date.current, returned_on: Date.current)
    @request.accept!

    assert_difference -> { Book.count } => 2 do
      @request.complete!(by: @bob)
    end
    assert @request.reload.completed?
    assert @request.completed_at.present?

    # Alice keeps her Hobbit - review, comments and all - as a book she's had.
    @hobbit.reload
    assert_equal @alice, @hobbit.user
    assert @hobbit.given_away?
    assert_equal @bob, @hobbit.given_to
    assert_equal "Alice's thoughts", @hobbit.review
    assert_equal "read", @hobbit.reading_status
    assert_includes @hobbit.comments, comment

    # Bob gets a fresh copy: the details, none of Alice's words.
    bobs_hobbit = @hobbit.successor
    assert_equal @bob, bobs_hobbit.user
    assert_equal [ "The Hobbit", "J.R.R. Tolkien" ], [ bobs_hobbit.title, bobs_hobbit.author ]
    assert_nil bobs_hobbit.review
    assert_nil bobs_hobbit.reading_status
    assert_empty bobs_hobbit.comments
    assert_equal @hobbit, bobs_hobbit.predecessor

    # ...and the same the other way for Dune.
    assert_equal @alice, @dune.reload.successor.user
    assert_not @dune.available_for_exchange?

    # The request still points at the givers' copies, and belongs to the original owner.
    assert_equal [ @dune, @hobbit ], [ @request.book, @request.offered_book ]
    assert_includes ExchangeRequest.received_by(@bob), @request
    assert_equal "swap_completed", @alice.notifications.first.kind
  end

  test "books_count counts books on the shelf, so a swap is one out, one in" do
    @request.accept!
    assert_difference -> { @alice.reload.books_count } => 0, -> { @bob.reload.books_count } => 0 do
      @request.complete!(by: @bob)
    end

    @request2 = ExchangeRequest.create!(requester: @bob, book: Book.create!(user: @alice, title: "Emma", author: "Austen", available_for_exchange: true))
    @request2.accept!
    assert_difference -> { @alice.reload.books_count } => -1, -> { @bob.reload.books_count } => 1 do
      @request2.complete!(by: @alice)
    end
  end

  test "ratings stay with the copy they were given on" do
    @dune.ratings.create!(user: @alice, score: 5)
    @request.accept!
    @request.complete!(by: @alice)

    assert @dune.reload.ratings.exists?(user: @alice) # on Bob's old copy, which isn't Alice's
    assert_equal 0, @dune.successor.ratings_count      # Alice's new copy starts unrated
  end

  test "the new copy gets its own copy of the cover" do
    @dune.cover.attach(io: file_fixture("cover.jpg").open, filename: "cover.jpg", content_type: "image/jpeg")
    @request.accept!
    @request.complete!(by: @alice)

    copy = @dune.reload.successor
    assert copy.cover_ready?
    assert_not_equal @dune.cover.blob.id, copy.cover.blob.id # deleting one never removes the other
  end
end
