require "test_helper"

class Users::BlocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    sign_in_as @alice
  end

  test "block and unblock from a conversation" do
    conversation = Conversation.between(@alice, @bob)

    post user_block_url(@bob), headers: { "Referer" => conversation_url(conversation) }
    assert @alice.blocking?(@bob)
    assert_redirected_to conversation_url(conversation)
    assert_match(/You've blocked Bob Bookworm/, flash[:notice])

    get conversation_url(conversation)
    assert_select "button", "Unblock"

    delete user_block_url(@bob)
    assert_not @alice.blocking?(@bob)
  end

  test "can't block yourself" do
    post user_block_url(@alice)
    assert_not @alice.blocking?(@alice)
    assert_equal "You can't block yourself.", flash[:alert]
  end
end
