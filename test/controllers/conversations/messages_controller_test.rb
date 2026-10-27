require "test_helper"

class Conversations::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    @conversation = Conversation.between(@alice, @bob)
    sign_in_as @alice
  end

  test "sending with Turbo adds the message in place" do
    post conversation_messages_url(@conversation), params: { direct_message: { body: "See you Saturday!" } }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=direct_messages]"
    assert_select "turbo-stream[action=replace][target=new_direct_message]"
    assert_equal "See you Saturday!", @conversation.messages.last.body
  end

  test "without JavaScript it goes back to the conversation" do
    post conversation_messages_url(@conversation), params: { direct_message: { body: "Hi" } }
    assert_redirected_to conversation_url(@conversation, anchor: "direct_message_#{@conversation.messages.last.id}")
  end

  test "an empty message shows an error" do
    post conversation_messages_url(@conversation), params: { direct_message: { body: "" } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert_select "turbo-stream[target=new_direct_message]"
    assert_equal 0, @conversation.messages.count
  end

  test "can't send when blocked" do
    @bob.blocks.create!(blocked: @alice)
    post conversation_messages_url(@conversation), params: { direct_message: { body: "Hello?" } }
    assert_equal 0, @conversation.messages.count
    assert_equal "You can't send messages to Bob Bookworm.", flash[:alert]
  end

  test "can't write in someone else's conversation" do
    other = Conversation.between(@bob, users(:admin))
    post conversation_messages_url(other), params: { direct_message: { body: "Hi" } }
    assert_response :not_found
    assert_equal 0, other.messages.count
  end

  test "members must confirm their email first" do
    @alice.update_columns(email_confirmed_at: nil)
    post conversation_messages_url(@conversation), params: { direct_message: { body: "Hi" } }
    assert_equal 0, @conversation.messages.count
    assert_match(/confirm your email/, flash[:alert])
  end
end
