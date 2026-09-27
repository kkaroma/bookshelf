require "test_helper"

class ExchangeRequestTest < ActiveSupport::TestCase
  setup do
    @alice  = users(:one)   # owns The Hobbit (not listed)
    @bob    = users(:two)   # owns Dune (listed for exchange)
    @admin  = users(:admin)
    @hobbit = books(:hobbit)
    @dune   = books(:dune)
    @pending = exchange_requests(:admin_wants_dune)
  end

  def build_request(**attributes)
    ExchangeRequest.new({ requester: @alice, book: @dune, offered_book: @hobbit, message: "Swap?" }.merge(attributes))
  end

  test "is valid for a listed book, offering one of your own" do
    assert build_request.valid?
  end

  test "offering a book in return is optional" do
    assert build_request(offered_book: nil).valid?
  end

  test "new requests are pending" do
    assert build_request.pending?
  end

  test "cannot request a book that isn't offered for exchange" do
    request = build_request(requester: @bob, book: @hobbit, offered_book: nil)
    assert_not request.valid?
    assert_includes request.errors[:book], "isn't offered for exchange"
  end

  test "cannot request your own book" do
    request = build_request(requester: @bob, offered_book: nil)
    assert_not request.valid?
    assert_includes request.errors[:base], "You can't request your own book"
  end

  test "the offered book must be your own" do
    other = Book.create!(user: @admin, title: "Not Alice's", author: "Someone")
    request = build_request(offered_book: other)
    assert_not request.valid?
    assert_includes request.errors[:offered_book], "must be one of your own books"
  end

  test "only one pending request per person per book" do
    duplicate = build_request(requester: @admin, offered_book: nil)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:book_id], "already has a request from you waiting for an answer"
  end

  test "the database also refuses a second pending request" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      ExchangeRequest.insert!({ requester_id: @admin.id, book_id: @dune.id, status: 0 })
    end
  end

  test "you can ask again after a request was declined" do
    @pending.decline!
    @dune.update!(available_for_exchange: true) # still listed
    assert build_request(requester: @admin, offered_book: nil).valid?
  end

  test "blank messages are stored as nil and long ones are rejected" do
    assert_nil build_request(message: "   ").message
    assert_not build_request(message: "x" * 1001).valid?
  end

  test "accepting marks it accepted and takes both books off the exchange shelf" do
    @hobbit.update!(available_for_exchange: true)
    request = build_request
    request.save!

    request.accept!

    assert request.accepted?
    assert request.responded_at.present?
    assert_not @dune.reload.available_for_exchange?
    assert_not @hobbit.reload.available_for_exchange?
  end

  test "accepting one request declines the others for the same book" do
    request = build_request
    request.save!

    request.accept!

    assert @pending.reload.declined?
    assert request.reload.accepted?
  end

  test "decline and cancel" do
    @pending.decline!
    assert @pending.declined?

    request = build_request
    request.save!
    request.cancel!
    assert request.cancelled?
  end

  test "a request can only be answered once" do
    @pending.decline!
    assert_raises(ExchangeRequest::AlreadyAnswered) { @pending.accept! }
  end

  test "taking a book off the exchange shelf declines pending requests" do
    @dune.update!(available_for_exchange: false)
    assert @pending.reload.declined?
  end

  test "received_by and sent_by" do
    assert_includes ExchangeRequest.received_by(@bob), @pending
    assert_not_includes ExchangeRequest.received_by(@alice), @pending
    assert_includes ExchangeRequest.sent_by(@admin), @pending
    assert_includes @bob.received_exchange_requests, @pending
    assert_includes @admin.sent_exchange_requests, @pending
  end

  test "deleting the offered book keeps the request but drops the offer" do
    request = build_request
    request.save!
    @hobbit.destroy
    assert_nil request.reload.offered_book
  end

  test "deleting the requested book deletes its requests" do
    assert_difference("ExchangeRequest.count", -1) { @dune.destroy }
  end
end
