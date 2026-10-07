class Book < ApplicationRecord
  include Flaggable

  belongs_to :user, counter_cache: true # keeps users.books_count up to date
  has_many :comments, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :loans, -> { order(lent_on: :desc, id: :desc) }, dependent: :destroy
  has_many :exchange_requests, dependent: :destroy
  # Requests where this book was offered in return; if it's deleted they just lose the offer.
  has_many :offered_in_exchange_requests, class_name: "ExchangeRequest",
           foreign_key: :offered_book_id, dependent: :nullify

  # Taking a book off the exchange shelf (or accepting a request for it)
  # declines everyone else who was still waiting.
  # When a book is offered for exchange, tell members who have it on their wishlist.
  after_commit :alert_wishlists, on: %i[ create update ],
               if: -> { available_for_exchange? && saved_change_to_available_for_exchange? }

  after_update :decline_pending_exchange_requests,
               if: -> { saved_change_to_available_for_exchange?(to: false) }

  # Search by title, subtitle, author or ISBN. Every word must match one of
  # those (so "tolkien hobbit" finds The Hobbit), ignoring upper/lower case.
  #   Book.search("hobbit")             Book.search("978-0-547-92822-7")
  scope :search, ->(query) {
    query.to_s.squish.split.first(MAX_SEARCH_WORDS).reduce(all) do |books, word|
      pattern = "%#{sanitize_sql_like(word)}%"
      isbn_digits = word.upcase.gsub(/[^0-9X]/, "")

      matches = where("books.title ILIKE :pattern OR books.subtitle ILIKE :pattern OR books.author ILIKE :pattern", pattern:)
      matches = matches.or(where("books.isbn LIKE ?", "%#{isbn_digits}%")) if isbn_digits.length >= 3
      books.merge(matches)
    end
  }
  MAX_SEARCH_WORDS = 5

  # Books whose owners are willing to swap them.
  scope :for_exchange, -> { where(available_for_exchange: true) }

  GENRES = [
    "Fiction", "Fantasy", "Science fiction", "Mystery & thriller", "Romance",
    "Historical fiction", "Children's", "Young adult", "Poetry",
    "Non-fiction", "Biography & memoir", "History", "Science & nature",
    "Business & money", "Self-help", "Religion & spirituality", "Cookery",
    "Art & design", "Other"
  ].freeze

  # The owner's reading of their copy. nil means "not set".
  enum :reading_status, { want_to_read: 0, reading: 1, read: 2 }, validate: { allow_nil: true }
  READING_STATUS_LABELS = { "want_to_read" => "Want to read", "reading" => "Reading", "read" => "Read" }.freeze

  COVER_TYPES = %w[ image/jpeg image/png image/webp ].freeze
  MAX_COVER_SIZE = 5.megabytes

  # The cover image, stored by Active Storage. Variants are resized copies,
  # made the first time each size is shown (using libvips).
  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 120, 180 ]
    attachable.variant :card,  resize_to_fill: [ 360, 540 ]
    attachable.variant :large, resize_to_fill: [ 600, 900 ]
  end

  # Form-only fields (not database columns):
  attribute :remove_cover, :boolean, default: false   # "Remove current cover" checkbox
  attribute :open_library_cover_id, :integer          # the cover picked from "Find cover online"

  normalizes :genre, with: ->(genre) { genre.strip.presence }

  # "978-0-547-92822-7" -> "9780547928227"
  normalizes :isbn, with: ->(isbn) { isbn.upcase.gsub(/[^0-9X]/, "").presence }

  # A review of only spaces is treated as "no review".
  normalizes :review, with: ->(review) { review.strip.presence }

  validates :title, :author, presence: true
  validates :subtitle, length: { maximum: 200 }
  validate :isbn_is_valid, if: -> { isbn.present? }
  validates :genre, inclusion: { in: GENRES, message: "isn't one of the listed genres" }, allow_nil: true
  validate :reading_dates_make_sense
  validate :attach_open_library_cover, if: -> { open_library_cover_id.present? }
  validate :cover_is_a_reasonable_image

  before_save :drop_cover, if: -> { remove_cover && !new_cover? }
  # Remember when the owner last wrote their review (for the activity feed).
  before_save -> { self.reviewed_at = review.present? ? Time.current : nil }, if: :will_save_change_to_review?
  validates :published_year,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: -> { Date.current.year } },
            allow_nil: true

  def owned_by?(someone)
    someone.present? && user_id == someone.id
  end

  # ISBNs end in a check digit, so typos can be caught.
  #   ISBN-10: weights 10..1, total divisible by 11 ("X" means 10)
  #   ISBN-13: weights 1,3,1,3..., total divisible by 10
  def self.valid_isbn?(isbn)
    digits = isbn.to_s.chars.map { |char| char == "X" ? 10 : char.to_i }

    case isbn.to_s
    when /\A\d{9}[\dX]\z/
      (digits.each_with_index.sum { |digit, i| digit * (10 - i) } % 11).zero?
    when /\A\d{13}\z/
      (digits.each_with_index.sum { |digit, i| digit * (i.even? ? 1 : 3) } % 10).zero?
    else
      false
    end
  end

  # A cover that's saved and ready to show (not a just-uploaded file that failed validation).
  def cover_ready?
    cover.attached? && cover.blob.persisted?
  end

  # The loan that hasn't come back yet, if the book is lent out.
  def current_loan
    loans.outstanding.first
  end

  # Hands the book to a new owner after a completed swap. The old owner's
  # review, reading status and lending history are theirs, so they're cleared;
  # the new owner's own rating is removed because owners can't rate their books.
  def transfer_to!(new_owner)
    transaction do
      loans.destroy_all
      ratings.where(user: new_owner).destroy_all
      update!(user: new_owner, review: nil, reviewed_at: nil, reading_status: nil,
              started_on: nil, finished_on: nil, available_for_exchange: false)
    end
  end

  def reading_status_label
    READING_STATUS_LABELS[reading_status]
  end

  # Changes the reading status and fills in the dates that go with it:
  # starting to read records today as the start date, finishing records
  # today as the finish date. Dates already filled in are kept.
  def update_reading_status!(status)
    today = Date.current
    case status.presence
    when "want_to_read" then update!(reading_status: status, started_on: nil, finished_on: nil)
    when "reading"      then update!(reading_status: status, started_on: started_on || today, finished_on: nil)
    when "read"         then update!(reading_status: status, finished_on: finished_on || today)
    when nil            then update!(reading_status: nil, started_on: nil, finished_on: nil)
    else raise ArgumentError, "Unknown reading status: #{status}"
    end
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
    # Each member hears about a given book once, however many matching wishlist
    # entries they have.
    def alert_wishlists
      WishlistItem.matching(self).includes(:user).map(&:user).uniq.each do |member|
        next if notifications.exists?(recipient: member, kind: "wishlist_match")

        Notification.notify(member, "wishlist_match", about: self, actor: user)
        NotificationsMailer.wishlist_match(member, self).deliver_later if member.notify_wishlist?
      end
    end

    def new_cover?
      attachment_changes["cover"].present?
    end

    def isbn_is_valid
      errors.add(:isbn, "isn't a valid ISBN (check for typos)") unless Book.valid_isbn?(isbn)
    end

    # Downloads the cover the member picked online. An uploaded file wins if
    # they did both. Only downloads once, even if validation runs again.
    def attach_open_library_cover
      return if new_cover? && @downloaded_cover_id.nil?
      return if @downloaded_cover_id == open_library_cover_id

      self.cover = OpenLibrary.download_cover(open_library_cover_id)
      @downloaded_cover_id = open_library_cover_id
    rescue OpenLibrary::Error => error
      errors.add(:cover, "couldn't be downloaded: #{error.message}. Try again, or upload an image instead")
    end

    def reading_dates_make_sense
      today = Date.current
      errors.add(:started_on, "can't be in the future") if started_on && started_on > today
      errors.add(:finished_on, "can't be in the future") if finished_on && finished_on > today
      if started_on && finished_on && finished_on < started_on
        errors.add(:finished_on, "can't be before the date you started")
      end
    end

    def cover_is_a_reasonable_image
      return unless new_cover? && cover.attached?

      unless COVER_TYPES.include?(cover.blob.content_type)
        errors.add(:cover, "must be a JPEG, PNG or WebP image")
      end
      if cover.blob.byte_size > MAX_COVER_SIZE
        errors.add(:cover, "must be smaller than 5 MB")
      end
    end

    def drop_cover
      cover.purge_later
    end

    def decline_pending_exchange_requests
      exchange_requests.pending.find_each(&:decline!)
    end
end
