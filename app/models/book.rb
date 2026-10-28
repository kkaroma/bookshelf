class Book < ApplicationRecord
  include Flaggable

  belongs_to :user
  # When a book leaves its owner's shelf it isn't deleted: it stays on their
  # profile under "Books I've had", with its review, comments and ratings.
  # After a swap, `given_to` is the new owner and `successor` their new copy.
  belongs_to :given_to, class_name: "User", optional: true
  belongs_to :successor, class_name: "Book", optional: true
  has_one :predecessor, class_name: "Book", foreign_key: :successor_id, inverse_of: :successor, dependent: :nullify
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

  # Books people have now, and ones that have left their shelf.
  scope :on_shelf, -> { where(given_away_at: nil) }
  scope :given_away, -> { where.not(given_away_at: nil) }
  # Copies made for a new owner by a swap (they have a predecessor).
  scope :not_from_swap, -> { where.not(id: Book.where.not(successor_id: nil).select(:successor_id)) }

  # users.books_count is the number of books on their shelf now. (One
  # after_commit with a condition: Rails keeps only the last of two
  # after_commit lines that name the same method.)
  after_commit :refresh_owner_books_count,
               if: -> { destroyed? || previously_new_record? || saved_change_to_given_away_at? }

  # Genres are managed by admins (Genre model, /admin/genres).

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
  # Any genre on the list, including retired ones (books keep those; the
  # form just doesn't offer them for new choices).
  validates :genre, inclusion: { in: ->(_book) { Genre.names }, message: "isn't one of the listed genres" }, allow_nil: true,
                    if: :will_save_change_to_genre?
  validate :reading_dates_make_sense
  validate :attach_open_library_cover, if: -> { open_library_cover_id.present? }
  validate :cover_is_a_reasonable_image

  before_save :drop_cover, if: -> { remove_cover && !new_cover? }
  # Remember when the owner last wrote their review (for the activity feed).
  before_save -> { self.reviewed_at = review.present? ? Time.current : nil }, if: :will_save_change_to_review?
  # Remember when it went on the Exchange shelf (cleared when it comes off).
  before_save -> { self.listed_for_exchange_at = available_for_exchange? ? Time.current : nil },
              if: :will_save_change_to_available_for_exchange?
  validate :not_offered_once_given_away
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

  def given_away? = given_away_at.present?

  # After a completed swap: the new owner gets their own copy (details and
  # cover, but none of this copy's review, comments, ratings or reading
  # history), and this copy stays with its old owner as a book they've had -
  # so their review and its discussion stay on their profile.
  # Returns the new copy.
  def hand_over_to!(new_owner)
    copy = transaction do
      new_copy = new_owner.books.create!(title:, subtitle:, author:, description:, published_year:, isbn:, genre:)
      loans.outstanding.update_all(returned_on: Date.current)
      update!(given_away_at: Time.current, given_to: new_owner, successor: new_copy, available_for_exchange: false)
      new_copy
    end
    copy_cover_to(copy)
    copy
  end

  # "I no longer have it" (given away outside the site, sold, lost...).
  def give_away!
    transaction do
      loans.outstanding.update_all(returned_on: Date.current)
      update!(given_away_at: Time.current, available_for_exchange: false)
    end
  end

  # Undo "I no longer have it". A book that went to someone in a swap can't
  # come back - they have their own copy now.
  def put_back_on_shelf!
    raise ArgumentError, "a swapped book can't be put back" if successor_id.present?

    update!(given_away_at: nil, given_to: nil)
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

  # Lending only makes sense for books you still have.
  def lendable_by?(someone)
    owned_by?(someone) && !given_away?
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
    def not_offered_once_given_away
      if given_away? && available_for_exchange?
        errors.add(:available_for_exchange, "isn't possible for a book you no longer have")
      end
    end

    def refresh_owner_books_count
      User.where(id: user_id).update_all(books_count: Book.on_shelf.where(user_id: user_id).count)
    end

    # The new owner gets their own copy of the cover file, so either of them
    # deleting their book never removes the other's cover. A failure here
    # just leaves the generated cover; the swap itself is already done.
    def copy_cover_to(copy)
      return unless cover_ready?

      copy.cover.attach(io: StringIO.new(cover.download), filename: cover.filename.to_s, content_type: cover.content_type)
    rescue ActiveStorage::Error, IOError => error
      Rails.logger.warn("Couldn't copy the cover of book #{id}: #{error.message}")
    end

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
