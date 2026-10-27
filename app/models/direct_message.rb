# One private message in a Conversation.
class DirectMessage < ApplicationRecord
  include Flaggable # the recipient can report it to the admins

  PER_MINUTE = 30 # anti-spam: messages one member can send in a minute

  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  scope :unread, -> { where(read_at: nil) }
  # Messages waiting for `user` to read them, in any of their conversations.
  scope :unread_for, ->(user) {
    unread.where.not(sender: user).where(conversation: Conversation.involving(user))
  }

  normalizes :body, with: ->(body) { body.strip }

  validates :body, presence: true, length: { maximum: 2000 }
  validate :sender_takes_part
  validate :conversation_open, on: :create
  validate :not_too_fast, on: :create

  after_create_commit :update_conversation, :email_recipient

  def recipient
    conversation.other_participant(sender)
  end

  # Flaggable reports compare against `user`: the person who wrote it.
  def user = sender
  def user_id = sender_id

  # Only the person it was sent to can report a private message - nobody
  # else can see it. (Admins too: they can't remove messages they receive.)
  def flaggable_by?(someone)
    someone.present? && conversation.participant?(someone) && sender_id != someone.id
  end

  private
    def sender_takes_part
      errors.add(:base, "You're not part of this conversation") unless conversation&.participant?(sender)
    end

    def conversation_open
      reason = conversation&.participant?(sender) && conversation.closed_reason_for(sender)
      errors.add(:base, reason) if reason
    end

    def not_too_fast
      if sender && DirectMessage.where(sender: sender, created_at: 1.minute.ago..).count >= PER_MINUTE
        errors.add(:base, "You're sending messages very quickly. Please wait a minute.")
      end
    end

    def update_conversation
      conversation.update_column(:last_message_at, created_at)
    end

    # Email only for the first unread message, so a chat doesn't flood their inbox.
    def email_recipient
      return unless recipient.notify_messages?

      waiting = conversation.unread_for(recipient).where.not(id: id).exists?
      NotificationsMailer.new_direct_message(self).deliver_later unless waiting
    end
end
