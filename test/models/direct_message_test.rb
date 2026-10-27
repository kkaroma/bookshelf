require "test_helper"

class DirectMessageTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alice = users(:one)
    @bob = users(:two)
    @conversation = Conversation.between(@alice, @bob)
  end

  def send_message(from: @alice, body: "Hello!")
    @conversation.messages.create!(sender: from, body: body)
  end

  test "a message needs text, at most 2000 characters" do
    assert_not @conversation.messages.build(sender: @alice, body: "   ").valid?
    assert_not @conversation.messages.build(sender: @alice, body: "a" * 2001).valid?
    assert @conversation.messages.build(sender: @alice, body: "a" * 2000).valid?
  end

  test "only the two members can write in a conversation" do
    message = @conversation.messages.build(sender: users(:admin), body: "Hi")
    assert_not message.valid?
    assert_includes message.errors.full_messages, "You're not part of this conversation"
  end

  test "a blocked member can't send" do
    @bob.blocks.create!(blocked: @alice)
    message = @conversation.messages.build(sender: @alice, body: "Hello?")
    assert_not message.valid?
    assert_includes message.errors.full_messages, "You can't send messages to Bob Bookworm."
  end

  test "at most #{DirectMessage::PER_MINUTE} messages a minute" do
    DirectMessage::PER_MINUTE.times { |i| send_message(body: "Message #{i}") }
    message = @conversation.messages.build(sender: @alice, body: "One more")
    assert_not message.valid?
    assert_match(/very quickly/, message.errors.full_messages.to_sentence)

    travel 61.seconds
    assert message.valid?
  end

  test "the first unread message is emailed; more while unread are not" do
    assert_enqueued_email_with NotificationsMailer, :new_direct_message, args: ->(args) { args.first.body == "Hello!" } do
      send_message
    end
    assert_no_enqueued_emails { send_message(body: "Are you there?") }

    @conversation.mark_read_for!(@bob)
    assert_enqueued_emails(1) { send_message(body: "Another day") }
  end

  test "no email when the recipient switched message emails off" do
    @bob.update!(notify_messages: false)
    assert_no_enqueued_emails { send_message }
  end

  test "messages don't go to the notification bell" do
    assert_no_difference("Notification.count") { send_message }
  end

  test "only the recipient can report a message" do
    message = send_message
    assert message.flaggable_by?(@bob)
    assert_not message.flaggable_by?(@alice)         # the sender
    assert_not message.flaggable_by?(users(:admin)) # not in the conversation
  end

  test "the email shows the message and links to the conversation" do
    message = send_message(body: "Is your copy of Dune still available?")
    email = NotificationsMailer.new_direct_message(message)

    assert_equal [ @bob.email_address ], email.to
    assert_equal "Alice Reader sent you a message on Bookshelf", email.subject
    assert_match "Is your copy of Dune still available?", email.text_part.body.to_s
    assert_match "/conversations/#{@conversation.id}", email.text_part.body.to_s
  end
end
