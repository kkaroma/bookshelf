# A member who doesn't want private messages from another member.
class Block < ApplicationRecord
  belongs_to :blocker, class_name: "User"
  belongs_to :blocked, class_name: "User"

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :not_yourself

  private
    def not_yourself
      errors.add(:base, "You can't block yourself") if blocker_id == blocked_id
    end
end
