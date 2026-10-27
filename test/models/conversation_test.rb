require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @bob = users(:two)
  end

  test "between finds the same conversation whoever starts it" do
    conversation = Conversation.between(@alice, @bob)
    assert_equal conversation, Conversation.between(@bob, @alice)
    assert_equal @alice, conversation.started_by
    assert_operator conversation.user_one_id, :<, conversation.user_two_id
  end

  test "the database allows only one conversation per pair" do
    Conversation.between(@alice, @bob)
    one, two = [ @alice, @bob ].sort_by(&:id)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Conversation.new(user_one: one, user_two: two, started_by: @alice).save!(validate: false)
    end
  end

  test "you can't start a conversation with yourself" do
    assert_raises(ActiveRecord::RecordInvalid) { Conversation.between(@alice, @alice) }
  end

  test "participants and the other person" do
    conversation = Conversation.between(@alice, @bob)
    assert conversation.participant?(@alice)
    assert conversation.participant?(@bob)
    assert_not conversation.participant?(users(:admin))
    assert_equal @bob, conversation.other_participant(@alice)
    assert_equal [ conversation ], @alice.conversations.to_a
  end

  test "only conversations with a message are listed" do
    conversation = Conversation.between(@alice, @bob)
    assert_empty @alice.conversations.with_messages

    conversation.messages.create!(sender: @alice, body: "Hello")
    assert_equal [ conversation ], @alice.conversations.with_messages.to_a
    assert_not_nil conversation.reload.last_message_at
  end

  test "unread messages and marking them read" do
    conversation = Conversation.between(@alice, @bob)
    conversation.messages.create!(sender: @alice, body: "One")
    conversation.messages.create!(sender: @alice, body: "Two")
    conversation.messages.create!(sender: @bob, body: "Mine")

    assert_equal 2, @bob.unread_messages_count
    assert_equal 1, @alice.unread_messages_count

    conversation.mark_read_for!(@bob)
    assert_equal 0, @bob.unread_messages_count
    assert_equal 1, @alice.unread_messages_count
  end

  test "blocking closes the conversation for both sides" do
    conversation = Conversation.between(@alice, @bob)
    assert_nil conversation.closed_reason_for(@alice)

    @bob.blocks.create!(blocked: @alice)
    assert_equal "You can't send messages to Bob Bookworm.", conversation.closed_reason_for(@alice)
    assert_match(/You've blocked Alice Reader/, conversation.closed_reason_for(@bob))
  end

  test "a suspended member can't be messaged" do
    conversation = Conversation.between(@alice, @bob)
    @bob.suspend!
    assert_equal "You can't send messages to Bob Bookworm.", conversation.closed_reason_for(@alice)
  end

  test "at most #{Conversation::NEW_PER_DAY} new conversations a day" do
    Conversation::NEW_PER_DAY.times do |i|
      other = User.create!(name: "Reader #{i}", email_address: "reader#{i}@example.com", password: "password123")
      Conversation.between(@alice, other)
    end

    error = assert_raises(ActiveRecord::RecordInvalid) { Conversation.between(@alice, @bob) }
    assert_match(/started a lot of conversations today/, error.message)

    travel 25.hours
    assert Conversation.between(@alice, @bob).persisted?
  end

  test "deleting an account deletes its conversations and messages" do
    conversation = Conversation.between(@alice, @bob)
    conversation.messages.create!(sender: @bob, body: "Hi")
    @bob.blocks.create!(blocked: @alice)

    assert_difference [ "Conversation.count", "DirectMessage.count", "Block.count" ], -1 do
      @bob.destroy!
    end
  end
end
