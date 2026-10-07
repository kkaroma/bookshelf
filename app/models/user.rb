class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :reading_goals, dependent: :destroy
  has_many :wishlist_items, -> { order(:title) }, dependent: :destroy
  has_many :flags, foreign_key: :reporter_id, inverse_of: :reporter, dependent: :destroy
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

  # Members who can use the site (suspended members can't sign in).
  scope :active, -> { where(suspended_at: nil) }

  # The link in the "confirm your email" email carries this token. It stops
  # working after 3 days, or as soon as the email address changes.
  generates_token_for :email_confirmation, expires_in: 3.days do
    email_address
  end

  # A new or changed email address needs confirming again.
  before_save :unconfirm_email, if: -> { persisted? && will_save_change_to_email_address? }
  after_commit :send_email_confirmation, on: %i[ create update ],
               if: -> { saved_change_to_email_address? && !email_confirmed? }

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

  def email_confirmed? = email_confirmed_at.present?

  def confirm_email!
    update!(email_confirmed_at: Time.current) unless email_confirmed?
  end

  def send_email_confirmation
    AccountMailer.email_confirmation(self).deliver_later
  end

  def suspended? = suspended_at.present?

  # Admins must be made members again before they can be suspended.
  def suspendable? = !admin? && !suspended?

  # Suspending signs the member out everywhere and stops them signing in. Their
  # books leave the Exchange shelf (which declines requests for them, telling
  # the requesters) and the requests they sent are cancelled.
  def suspend!
    raise ArgumentError, "admins can't be suspended" if admin?

    transaction do
      update!(suspended_at: Time.current)
      sessions.destroy_all
      books.for_exchange.find_each { |book| book.update!(available_for_exchange: false) }
      sent_exchange_requests.pending.find_each(&:cancel!)
    end
  end

  def reinstate!
    update!(suspended_at: nil)
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

  private
    def unconfirm_email
      self.email_confirmed_at = nil
    end
end
