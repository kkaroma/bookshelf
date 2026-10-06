class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :reading_goals, dependent: :destroy
  has_many :wishlist_items, -> { order(:title) }, dependent: :destroy
  has_many :notifications, -> { newest_first }, foreign_key: :recipient_id, inverse_of: :recipient, dependent: :destroy
  # Notifications others received about something this person did. If they
  # delete their account, those stay but no longer name them.
  has_many :caused_notifications, class_name: "Notification", foreign_key: :actor_id,
           inverse_of: :actor, dependent: :nullify

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
  has_many :received_exchange_requests, class_name: "ExchangeRequest", foreign_key: :owner_id,
           inverse_of: :owner, dependent: :destroy

  # Stored as a number in the database (0 or 1), used by name in code:
  # user.admin?, user.member?, user.admin!, User.admins
  enum :role, { member: 0, admin: 1 }, default: :member, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }
  normalizes :city, with: ->(city) { city.squish.presence }

  validates :name, presence: true, length: { maximum: 50 }
  validates :city, length: { maximum: 60 }

  # Is this person in the same town? (Ignores capital letters.)
  def same_city_as?(other)
    city.present? && other&.city.present? && city.casecmp?(other.city)
  end
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def wishlisted?(book)
    wishlist_items.any? { |item| item.matches?(book) }
  end

  def reading_goal_for(year = Date.current.year)
    reading_goals.find_by(year: year)
  end

  # The site must always have at least one admin.
  def last_admin?
    admin? && User.admin.count == 1
  end

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
