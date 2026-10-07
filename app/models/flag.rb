# A member reporting a book or comment as inappropriate. Admins see open
# reports at /admin/flags and either remove the thing or dismiss the report.
class Flag < ApplicationRecord
  REASONS = {
    "spam"      => "Spam or advertising",
    "offensive" => "Rude, hateful or offensive",
    "wrong"     => "Wrong or misleading information",
    "other"     => "Something else"
  }.freeze

  belongs_to :reporter, class_name: "User"
  belongs_to :flaggable, polymorphic: true
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :notifications, as: :notifiable, dependent: :destroy

  scope :unresolved, -> { where(resolved_at: nil) }

  normalizes :note, with: ->(note) { note.strip.presence }

  validates :reason, inclusion: { in: REASONS.keys, message: "must be chosen" }
  validates :note, length: { maximum: 1000 }
  validates :note, presence: { message: "can't be blank when you choose “Something else”" }, if: -> { reason == "other" }
  validates :flaggable_type, inclusion: { in: %w[Book Comment] }
  validate :reporter_may_flag, on: :create
  validate :not_already_reported, on: :create

  after_create_commit :tell_admins

  def reason_label = REASONS.fetch(reason, reason)
  def resolved? = resolved_at.present?

  # How many different books/comments are waiting for an admin (several
  # reports about the same comment count once).
  def self.reported_items_count
    unresolved.group(:flaggable_type, :flaggable_id).count.size
  end

  # Admin decided the reports about an item need no action.
  def self.dismiss_all_for(flaggable, by:)
    where(flaggable: flaggable).unresolved.update_all(resolved_at: Time.current, resolved_by_id: by.id)
  end

  private
    def reporter_may_flag
      if flaggable && reporter && !flaggable.flaggable_by?(reporter)
        errors.add(:base, "You can't report this")
      end
    end

    def not_already_reported
      if Flag.unresolved.exists?(reporter: reporter, flaggable: flaggable)
        errors.add(:base, "You've already reported this. An admin will look at it soon.")
      end
    end

    def tell_admins
      User.admin.active.find_each do |admin|
        Notification.notify(admin, "new_flag", about: self, actor: reporter)
        NotificationsMailer.new_flag(self, admin).deliver_later
      end
    end
end
