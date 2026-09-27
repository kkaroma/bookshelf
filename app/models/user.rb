class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy

  # Following: a user follows many users and is followed by many users.
  # Both sides go through the same follows table, looked at from each end.
  has_many :active_follows,  class_name: "Follow", foreign_key: :follower_id,
                             inverse_of: :follower, dependent: :destroy
  has_many :passive_follows, class_name: "Follow", foreign_key: :followed_id,
                             inverse_of: :followed, dependent: :destroy
  has_many :following, through: :active_follows,  source: :followed # people I follow
  has_many :followers, through: :passive_follows, source: :follower # people who follow me

  # Exchange requests I've sent, and ones others sent me for my books.
  has_many :sent_exchange_requests, class_name: "ExchangeRequest", foreign_key: :requester_id,
           inverse_of: :requester, dependent: :destroy
  has_many :received_exchange_requests, through: :books, source: :exchange_requests

  # Stored as a number in the database (0 or 1), used by name in code:
  # user.admin?, user.member?, user.admin!, User.admins
  enum :role, { member: 0, admin: 1 }, default: :member, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :name, presence: true, length: { maximum: 50 }
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def follow(other)
    active_follows.create!(followed: other)
  ensure
    @following_ids = nil
  end

  def unfollow(other)
    active_follows.find_by(followed: other)&.destroy
  ensure
    @following_ids = nil
  end

  # Loads the IDs of everyone I follow once, so a page listing many
  # members can ask "do I follow them?" without a query per person.
  def following?(other)
    @following_ids ||= active_follows.pluck(:followed_id).to_set
    @following_ids.include?(other.id)
  end
end
