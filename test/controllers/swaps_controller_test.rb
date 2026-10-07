require "test_helper"

# The request page, its conversation, and marking a swap as done.
class SwapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    @swap = ExchangeRequest.create!(requester: @alice, book: books(:dune), offered_book: books(:hobbit))
    sign_in_as @alice
  end

  test "the request page shows the conversation to the two people involved" do
    @swap.messages.create!(sender: @bob, body: "Saturday at the library?")
    get exchange_request_url(@swap)

    assert_response :success
    assert_select "h2", "Messages with Bob Bookworm"
    assert_select ".message.is-theirs", /Saturday at the library/
    assert_select "form#new_message textarea[name=?]", "message[body]"
  end

  test "outsiders can't see a request or post in it" do
    sign_out
    sign_in_as users(:admin)
    get exchange_request_url(@swap)
    assert_response :not_found

    assert_no_difference("Message.count") do
      post exchange_request_messages_url(@swap), params: { message: { body: "Hi" } }
    end
    assert_response :not_found
  end

  test "sending a message with Turbo adds it in place" do
    post exchange_request_messages_url(@swap), params: { message: { body: "See you Saturday!" } }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=append][target=messages]"
    assert_select "turbo-stream[action=replace][target=new_message]"
    assert_equal "See you Saturday!", @swap.messages.last.body
  end

  test "without JavaScript, sending a message goes back to the conversation" do
    post exchange_request_messages_url(@swap), params: { message: { body: "See you Saturday!" } }
    message = @swap.messages.last
    assert_redirected_to exchange_request_url(@swap, anchor: "message_#{message.id}")
  end

  test "opening the request marks its message notifications read" do
    @swap.messages.create!(sender: @bob, body: "Hello")
    assert_equal 1, @alice.notifications.unread.where(kind: "new_message").count
    get exchange_request_url(@swap)
    assert_equal 0, @alice.notifications.unread.where(kind: "new_message").count
  end

  test "no messages once a request is closed" do
    @swap.cancel!
    get exchange_request_url(@swap)
    assert_select "form#new_message", count: 0
    post exchange_request_messages_url(@swap), params: { message: { body: "Hi" } }
    assert_equal 0, @swap.messages.count
  end

  test "request cards link to the conversation" do
    get exchange_requests_url(box: "sent")
    assert_select ".request a[href=?]", exchange_request_path(@swap), text: /Send a message/
  end

  test "marking an accepted swap as done moves the books" do
    @swap.accept!
    get exchange_request_url(@swap)
    assert_select "button", "Mark swap as done"

    patch complete_exchange_request_url(@swap)
    assert_redirected_to exchange_request_path(@swap)
    assert @swap.reload.completed?
    assert_equal @alice, books(:dune).reload.user

    follow_redirect!
    assert_select ".flash-notice", /Swap done! “Dune” is now on your shelf/
    assert_select ".status-completed", "Completed"
  end

  test "a pending request can't be marked done" do
    patch complete_exchange_request_url(@swap)
    assert @swap.reload.pending?
    follow_redirect!
    assert_select ".flash-alert", /Only accepted requests/
  end

  test "only the original owner can accept, even later" do
    sign_out
    sign_in_as @bob
    patch accept_exchange_request_url(@swap)
    assert @swap.reload.accepted?
  end
end
