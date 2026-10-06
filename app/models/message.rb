# A message between the two people in an exchange request.
class Message < ApplicationRecord
  belongs_to :exchange_request
  belongs_to :sender, class_name: "User"
  has_many :notifications, as: :notifiable, dependent: :destroy

  normalizes :body, with: ->(body) { body.strip }

  validates :body, presence: true, length: { maximum: 2000 }
  validate :sender_takes_part

  after_create_commit :tell_recipient

  def recipient
    exchange_request.other_party(sender)
  end

  private
    def sender_takes_part
      errors.add(:sender, "isn't part of this exchange") unless exchange_request&.participant?(sender)
    end

    # The bell for every message; an email only for the first unread one in the
    # conversation, so a chat doesn't flood their inbox.
    def tell_recipient
      earlier = exchange_request.messages.where.not(id: id).select(:id)
      waiting = recipient.notifications.unread.where(kind: "new_message", notifiable_type: "Message", notifiable_id: earlier).exists?

      Notification.notify(recipient, "new_message", about: self, actor: sender)
      NotificationsMailer.new_message(self).deliver_later if recipient.notify_messages? && !waiting
    end
end
