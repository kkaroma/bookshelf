class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :comments, dependent: :destroy

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
end
