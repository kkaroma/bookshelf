require "test_helper"

class Users::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    sign_in_as @alice
  end

  test "profiles have a Message button, except your own" do
    get user_url(@bob)
    assert_select ".profile-actions form[action=?]", user_conversation_path(@bob)

    get user_url(@alice)
    assert_select ".profile-actions", 0
  end

  test "Message opens a new or existing conversation" do
    assert_difference("Conversation.count") { post user_conversation_url(@bob) }
    conversation = Conversation.last
    assert_redirected_to conversation_url(conversation, anchor: "new_direct_message")

    assert_no_difference("Conversation.count") { post user_conversation_url(@bob) }
  end

  test "can't message yourself or a suspended member" do
    post user_conversation_url(@alice)
    assert_equal "You can't message yourself.", flash[:alert]

    @bob.suspend!
    post user_conversation_url(@bob)
    assert_response :not_found
    assert_equal 0, Conversation.count
  end

  test "unconfirmed members can't start conversations" do
    @alice.update_columns(email_confirmed_at: nil)
    assert_no_difference("Conversation.count") { post user_conversation_url(@bob) }
  end
end
