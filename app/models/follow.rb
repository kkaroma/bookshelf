# "follower follows followed". Both are Users.
class Follow < ApplicationRecord
  # counter_cache keeps users.following_count / users.followers_count up to date.
  belongs_to :follower, class_name: "User", counter_cache: :following_count
  belongs_to :followed, class_name: "User", counter_cache: :followers_count

  validates :followed_id, uniqueness: { scope: :follower_id, message: "is already being followed" }
  validate :not_following_yourself

  after_create_commit :email_followed

  private
    def email_followed
      NotificationsMailer.new_follower(self).deliver_later if followed.notify_followers?
    end

    def not_following_yourself
      errors.add(:base, "You can't follow yourself") if follower_id.present? && follower_id == followed_id
    end
end
