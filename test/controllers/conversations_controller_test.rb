require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    @conversation = Conversation.between(@alice, @bob)
    sign_in_as @alice
  end

  test "an empty inbox explains how to start" do
    get conversations_url
    assert_response :success
    assert_select ".empty-state h2", "No messages yet"
  end

  test "the inbox lists conversations with the latest message and unread count" do
    @conversation.messages.create!(sender: @alice, body: "Hi Bob")
    @conversation.messages.create!(sender: @bob, body: "Hello Alice! Want to swap?")

    get conversations_url
    assert_select ".conversation-row", 1
    assert_select "#conversation_#{@conversation.id}.is-unread"
    assert_select "#conversation_#{@conversation.id} strong", "Bob Bookworm"
    assert_select "#conversation_#{@conversation.id} .conversation-preview", "Hello Alice! Want to swap?"
    assert_select "#conversation_#{@conversation.id} .nav-count", "1"
  end

  test "the header shows unread messages" do
    @conversation.messages.create!(sender: @bob, body: "Hi")
    get root_url
    assert_select "a.bell[href=?][aria-label=?] .bell-count", conversations_path, "Messages (1 unread)", "1"
  end

  test "opening a conversation shows it and marks it read" do
    @conversation.messages.create!(sender: @bob, body: "Hi Alice")
    get conversation_url(@conversation)

    assert_response :success
    assert_select "h1", "Bob Bookworm"
    assert_select ".message.is-theirs .message-body", "Hi Alice"
    assert_select "form#new_direct_message textarea"
    assert_equal 0, @alice.unread_messages_count
  end

  test "nobody else can open a conversation - not even admins" do
    sign_out
    sign_in_as users(:admin)
    get conversation_url(@conversation)
    assert_response :not_found
  end

  test "a blocked conversation says why instead of showing the box" do
    @bob.blocks.create!(blocked: @alice)
    get conversation_url(@conversation)
    assert_select ".conversation-closed", "You can't send messages to Bob Bookworm."
    assert_select "form#new_direct_message", 0
  end
end
