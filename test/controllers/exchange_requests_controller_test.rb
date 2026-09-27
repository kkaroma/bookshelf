require "test_helper"

class ExchangeRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice  = users(:one)   # owns The Hobbit
    @bob    = users(:two)   # owns Dune (listed for exchange)
    @admin  = users(:admin) # has a pending request for Dune
    @hobbit = books(:hobbit)
    @dune   = books(:dune)
    @pending = exchange_requests(:admin_wants_dune)
  end

  # --- Asking for a book ---

  test "request form lists your own books to offer" do
    sign_in_as @alice
    get new_book_exchange_request_url(@dune)

    assert_response :success
    assert_select "h1", "Request an exchange"
    assert_select "select[name=?] option", "exchange_request[offered_book_id]", text: "The Hobbit"
  end

  test "cannot open the form for a book that isn't listed, or your own" do
    sign_in_as @bob
    get new_book_exchange_request_url(@hobbit) # not listed
    assert_redirected_to book_url(@hobbit)

    get new_book_exchange_request_url(@dune) # Bob's own
    assert_redirected_to book_url(@dune)
  end

  test "send a request with an offer and a message" do
    sign_in_as @alice

    assert_difference("ExchangeRequest.count") do
      post book_exchange_requests_url(@dune), params: {
        exchange_request: { offered_book_id: @hobbit.id, message: "Swap you The Hobbit?" }
      }
    end

    request = ExchangeRequest.last
    assert_equal @alice, request.requester
    assert_equal @hobbit, request.offered_book
    assert request.pending?
    assert_redirected_to exchange_requests_url(box: "sent")
  end

  test "cannot offer someone else's book" do
    sign_in_as @admin
    ExchangeRequest.delete_all

    assert_no_difference("ExchangeRequest.count") do
      post book_exchange_requests_url(@dune), params: { exchange_request: { offered_book_id: @hobbit.id } }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /must be one of your own books/
  end

  test "cannot send a second request while one is waiting" do
    sign_in_as @admin
    assert_no_difference("ExchangeRequest.count") do
      post book_exchange_requests_url(@dune), params: { exchange_request: { message: "Again!" } }
    end
    assert_response :unprocessable_content
  end

  # --- The requests page ---

  test "received tab shows requests for my books with Accept and Decline" do
    sign_in_as @bob
    get exchange_requests_url

    assert_select ".tab.active", /Received/
    assert_select ".request", 1
    assert_select ".request-summary", /Ada Admin would like your book\s+Dune/
    assert_select ".request-message", /always wanted to read/
    assert_select ".request button", "Accept"
    assert_select ".request button", "Decline"
  end

  test "sent tab shows my requests with Cancel" do
    sign_in_as @admin
    get exchange_requests_url(box: "sent")

    assert_select ".tab.active", "Sent"
    assert_select ".request-summary", /You asked\s+Bob Bookworm\s+for\s+Dune/
    assert_select ".request button", "Cancel request"
    assert_select ".request button", text: "Accept", count: 0
  end

  test "empty tabs show a friendly message" do
    sign_in_as @alice
    get exchange_requests_url
    assert_select ".empty-state h2", "No requests yet"
  end

  test "header shows how many requests are waiting for you" do
    sign_in_as @bob
    get books_url
    assert_select ".nav-count", "1"

    sign_out
    sign_in_as @alice
    get books_url
    assert_select ".nav-count", count: 0
  end

  # --- Answering ---

  test "owner accepts a request and then sees the requester's email" do
    sign_in_as @bob
    patch accept_exchange_request_url(@pending)

    assert_redirected_to exchange_requests_url
    assert @pending.reload.accepted?
    assert_not @dune.reload.available_for_exchange?

    follow_redirect!
    assert_select ".request-contact a[href=?]", "mailto:#{@admin.email_address}"
  end

  test "owner declines a request" do
    sign_in_as @bob
    patch decline_exchange_request_url(@pending)
    assert @pending.reload.declined?
  end

  test "only the owner can accept or decline" do
    sign_in_as @alice
    patch accept_exchange_request_url(@pending)
    patch decline_exchange_request_url(@pending)

    assert @pending.reload.pending?
  end

  test "the requester cannot accept their own request" do
    sign_in_as @admin
    patch accept_exchange_request_url(@pending)
    assert @pending.reload.pending?
  end

  test "requester can cancel" do
    sign_in_as @admin
    patch cancel_exchange_request_url(@pending)

    assert @pending.reload.cancelled?
    assert_redirected_to exchange_requests_url(box: "sent")
  end

  test "only the requester can cancel" do
    sign_in_as @bob
    patch cancel_exchange_request_url(@pending)
    assert @pending.reload.pending?
  end

  test "answering a request twice shows a message instead of an error" do
    sign_in_as @bob
    patch decline_exchange_request_url(@pending)
    patch accept_exchange_request_url(@pending)

    assert @pending.reload.declined?
    follow_redirect!
    assert_select ".flash-alert", /already been answered/
  end

  # --- The book page ---

  test "book page invites you to request a listed book" do
    sign_in_as @alice
    get book_url(@dune)
    assert_select ".exchange-panel a", "Request exchange"
  end

  test "book page reminds you of your waiting request" do
    sign_in_as @admin
    get book_url(@dune)
    assert_select ".exchange-panel", /You asked Bob Bookworm for this book/
    assert_select ".exchange-panel button", "Cancel request"
  end

  test "book page tells the owner how many people are asking" do
    sign_in_as @bob
    get book_url(@dune)
    assert_select ".exchange-panel", /1 person\s+would like to swap/
    assert_select ".exchange-panel a", "Review requests"
  end

  test "signed-out visitors are sent to sign in" do
    get exchange_requests_url
    assert_redirected_to new_session_url
  end
end
