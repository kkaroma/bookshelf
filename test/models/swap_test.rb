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

  test "completing a swap moves both books to their new owners" do
    @hobbit.update!(review: "Alice's thoughts", reading_status: "read", finished_on: Date.current)
    @hobbit.loans.create!(borrower_name: "Sam", lent_on: Date.current, returned_on: Date.current)
    @request.accept!

    assert_difference -> { @alice.reload.books_count } => 0, -> { @bob.reload.books_count } => 0 do # one each way
      @request.complete!(by: @bob)
    end

    assert @request.reload.completed?
    assert @request.completed_at.present?
    assert_equal @alice, @dune.reload.user
    assert_equal @bob, @hobbit.reload.user

    # The previous owner's private details don't travel with the book
    assert_nil @hobbit.review
    assert_nil @hobbit.reading_status
    assert_empty @hobbit.loans
    assert_not @dune.available_for_exchange?

    # The requests still belong to the original owner
    assert_includes ExchangeRequest.received_by(@bob), @request
    assert_equal "swap_completed", @alice.notifications.first.kind
  end

  test "counter caches follow the books" do
    @request.update!(offered_book: nil)
    @request.accept!
    assert_difference -> { @alice.reload.books_count } => 1, -> { @bob.reload.books_count } => -1 do
      @request.complete!(by: @alice)
    end
  end

  test "the new owner's own rating is removed (owners can't rate their books)" do
    @dune.ratings.create!(user: @alice, score: 5)
    @request.accept!
    @request.complete!(by: @alice)
    assert_not @dune.ratings.exists?(user: @alice)
    assert_equal 0, @dune.reload.ratings_count
  end
end
