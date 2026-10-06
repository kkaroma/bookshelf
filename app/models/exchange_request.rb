# A member asking to swap for someone else's book.
# The requester may offer one of their own books in return.
class ExchangeRequest < ApplicationRecord
  # Raised when someone tries to answer a request that isn't pending any more.
  class AlreadyAnswered < StandardError; end

  belongs_to :requester, class_name: "User"
  # Who owned the book when it was requested (remembered, because completing
  # the swap moves the book to the requester).
  belongs_to :owner, class_name: "User"
  belongs_to :book
  has_many :messages, -> { order(:created_at, :id) }, dependent: :destroy
  belongs_to :offered_book, class_name: "Book", optional: true
  has_many :notifications, as: :notifiable, dependent: :destroy

  # Raised when a swap is marked done before it was accepted.
  class NotAccepted < StandardError; end

  enum :status, { pending: 0, accepted: 1, declined: 2, cancelled: 3, completed: 4 }, default: :pending

  before_validation :remember_owner, on: :create

  normalizes :message, with: ->(message) { message.strip.presence }

  validates :message, length: { maximum: 1000 }
  validates :book_id, uniqueness: { scope: :requester_id, conditions: -> { pending },
                                    message: "already has a request from you waiting for an answer" },
                      if: :pending?
  validate :book_is_available, on: :create
  validate :not_your_own_book, on: :create
  validate :offered_book_is_yours

  # Emails (each only if the recipient has "Exchange requests" switched on).
  after_create_commit :tell_owner
  after_update_commit :tell_requester, if: -> { saved_change_to_status? && (accepted? || declined?) }

  # Requests people have sent me, i.e. for books I own.
  scope :received_by, ->(user) { where(owner: user) }
  scope :sent_by,     ->(user) { where(requester: user) }
  scope :newest_first, -> { order(created_at: :desc) }


  def participant?(user)
    user.present? && (requester_id == user.id || owner_id == user.id)
  end

  # The other person in the conversation.
  def other_party(user)
    user.id == requester_id ? owner : requester
  end

  # Messages can be sent while the request is waiting or agreed, not after.
  def open_for_messages? = pending? || accepted?

  # Either person confirms the swap happened. The books change owners: the
  # requested book goes to the requester, and the offered one to the owner.
  def complete!(by:)
    raise NotAccepted, "Only accepted requests can be marked as done" unless accepted?

    transaction do
      update!(status: :completed, completed_at: Time.current)
      book.transfer_to!(requester)
      offered_book&.transfer_to!(owner)
    end
    Notification.notify(other_party(by), "swap_completed", about: self, actor: by)
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

    # The bell always; email only if they have "Exchange requests" switched on.
    def tell_owner
      Notification.notify(owner, "exchange_request_received", about: self, actor: requester)
      NotificationsMailer.exchange_request_received(self).deliver_later if owner.notify_exchange_requests?
    end

    def tell_requester
      Notification.notify(requester, "exchange_request_#{status}", about: self, actor: (owner if accepted?))
      NotificationsMailer.exchange_request_answered(self).deliver_later if requester.notify_exchange_requests?
    end

    def remember_owner
      self.owner ||= book&.user
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
