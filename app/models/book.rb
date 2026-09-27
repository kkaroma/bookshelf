class Book < ApplicationRecord
  belongs_to :user, counter_cache: true # keeps users.books_count up to date
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :exchange_requests, dependent: :destroy
  # Requests where this book was offered in return; if it's deleted they just lose the offer.
  has_many :offered_in_exchange_requests, class_name: "ExchangeRequest",
           foreign_key: :offered_book_id, dependent: :nullify

  # Taking a book off the exchange shelf (or accepting a request for it)
  # declines everyone else who was still waiting.
  after_update :decline_pending_exchange_requests,
               if: -> { saved_change_to_available_for_exchange?(to: false) }

  # Books whose owners are willing to swap them.
  scope :for_exchange, -> { where(available_for_exchange: true) }

  # A review of only spaces is treated as "no review".
  normalizes :review, with: ->(review) { review.strip.presence }

  validates :title, :author, presence: true
  validates :subtitle, length: { maximum: 200 }
  validates :published_year,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true

  def owned_by?(someone)
    someone.present? && user_id == someone.id
  end

  # Anyone signed in can rate a book, except the person who added it.
  def rateable_by?(someone)
    someone.present? && !owned_by?(someone)
  end

  # Recalculates the cached ratings_count and average_rating columns.
  # The database does the maths (COUNT and AVG), not Ruby.
  def refresh_rating_stats!
    update_columns(ratings_count: ratings.count, average_rating: ratings.average(:score)&.round(1))
  end

  # Anyone signed in can ask to swap for a listed book, except its owner.
  def requestable_by?(someone)
    someone.present? && available_for_exchange? && !owned_by?(someone)
  end

  # The owner can change their own book; admins can change any book.
  def editable_by?(someone)
    owned_by?(someone) || someone&.admin? || false
  end

  private
    def decline_pending_exchange_requests
      exchange_requests.pending.find_each(&:decline!)
    end
end
