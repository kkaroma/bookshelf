# A private conversation between two members. There's only ever one per pair:
# the two user ids are stored smallest first, and a unique index (plus a
# database check) makes sure of it.
class Conversation < ApplicationRecord
  NEW_PER_DAY = 20 # anti-spam: conversations one member can start in a day

  belongs_to :user_one, class_name: "User"
  belongs_to :user_two, class_name: "User"
  belongs_to :started_by, class_name: "User"
  has_many :messages, -> { order(:created_at, :id) }, class_name: "DirectMessage",
           inverse_of: :conversation, dependent: :destroy

  # Conversations this member is part of.
  scope :involving, ->(user) { where(user_one: user).or(where(user_two: user)) }
  # Only ones with at least one message (opening an empty one doesn't list it).
  scope :with_messages, -> { where.not(last_message_at: nil) }

  validate :two_different_members
  validate :not_too_many_new_today, on: :create

  # The conversation between two members, started if there isn't one yet.
  def self.between(member, other)
    one, two = [ member, other ].sort_by(&:id)
    find_or_create_by!(user_one: one, user_two: two) { |conversation| conversation.started_by = member }
  rescue ActiveRecord::RecordNotUnique
    retry # both started it at the same moment; the next try finds it
  end

  def participant?(user)
    user.present? && (user_one_id == user.id || user_two_id == user.id)
  end

  def other_participant(user)
    user_one_id == user.id ? user_two : user_one
  end

  def unread_for(user)
    messages.unread.where.not(sender: user)
  end

  def mark_read_for!(user)
    unread_for(user).update_all(read_at: Time.current)
  end

  # Why `user` can't send a message here right now, or nil if they can.
  def closed_reason_for(user)
    other = other_participant(user)
    if user.blocking?(other)
      "You've blocked #{other.name}. Unblock them to send messages."
    elsif other.blocking?(user) || other.suspended?
      "You can't send messages to #{other.name}."
    end
  end

  private
    def two_different_members
      errors.add(:base, "You can't message yourself") if user_one_id.present? && user_one_id == user_two_id
    end

    def not_too_many_new_today
      return if started_by.nil?

      if Conversation.where(started_by: started_by, created_at: 1.day.ago..).count >= NEW_PER_DAY
        errors.add(:base, "You've started a lot of conversations today. Please try again tomorrow.")
      end
    end
end
