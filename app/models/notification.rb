# An in-app notification (the bell): "Bob commented on The Hobbit".
#
# `notifiable` is what it's about - a Comment, Follow, ExchangeRequest, Message,
# Book or Flag. It's a *polymorphic* association: one pair of columns
# (notifiable_type + notifiable_id) that can point at any of those.
class Notification < ApplicationRecord
  KINDS = %w[
    exchange_request_received exchange_request_accepted exchange_request_declined
    swap_completed new_message new_comment new_reply new_follower wishlist_match
    new_flag
  ].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Creates a notification, unless it would be telling people about their own action.
  def self.notify(recipient, kind, about:, actor: nil)
    return if recipient.nil? || recipient == actor

    create!(recipient: recipient, kind: kind, notifiable: about, actor: actor)
  end

  def read? = read_at.present?

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
