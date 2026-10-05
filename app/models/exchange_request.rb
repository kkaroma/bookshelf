# A member asking to swap for someone else's book.
# The requester may offer one of their own books in return.
class ExchangeRequest < ApplicationRecord
  # Raised when someone tries to answer a request that isn't pending any more.
  class AlreadyAnswered < StandardError; end

  belongs_to :requester, class_name: "User"
  belongs_to :book
  belongs_to :offered_book, class_name: "Book", optional: true

  enum :status, { pending: 0, accepted: 1, declined: 2, cancelled: 3 }, default: :pending

  normalizes :message, with: ->(message) { message.strip.presence }

  validates :message, length: { maximum: 1000 }
  validates :book_id, uniqueness: { scope: :requester_id, conditions: -> { pending },
                                    message: "already has a request from you waiting for an answer" },
                      if: :pending?
  validate :book_is_available, on: :create
  validate :not_your_own_book, on: :create
  validate :offered_book_is_yours

  # Emails (each only if the recipient has "Exchange requests" switched on).
  after_create_commit :email_owner
  after_update_commit :email_requester, if: -> { saved_change_to_status? && (accepted? || declined?) }

  # Requests people have sent me, i.e. for books I own.
  scope :received_by, ->(user) { joins(:book).where(books: { user_id: user.id }) }
  scope :sent_by,     ->(user) { where(requester: user) }
  scope :newest_first, -> { order(created_at: :desc) }

  def owner
    book.user
  end

  # Owner says yes. The book (and the one offered in return) leave the
  # exchange shelf; Book then declines any other requests still waiting.
  def accept!
    respond_with!(:accepted) do
      book.update!(available_for_exchange: false)
      offered_book&.update!(available_for_exchange: false)
    end
  end

  def decline!
    respond_with!(:declined)
  end

  # The requester changes their mind.
  def cancel!
    respond_with!(:cancelled)
  end

  private
    def respond_with!(new_status)
      raise AlreadyAnswered, "This request has already been #{status}" unless pending?

      transaction do
        update!(status: new_status, responded_at: Time.current)
        yield if block_given?
      end
    end

    def email_owner
      NotificationsMailer.exchange_request_received(self).deliver_later if owner.notify_exchange_requests?
    end

    def email_requester
      NotificationsMailer.exchange_request_answered(self).deliver_later if requester.notify_exchange_requests?
    end

    def book_is_available
      errors.add(:book, "isn't offered for exchange") if book && !book.available_for_exchange?
    end

    def not_your_own_book
      errors.add(:base, "You can't request your own book") if book && book.user_id == requester_id
    end

    def offered_book_is_yours
      if offered_book && offered_book.user_id != requester_id
        errors.add(:offered_book, "must be one of your own books")
      end
    end
end
