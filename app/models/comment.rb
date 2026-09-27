class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :book

  # Replies: a comment can answer another comment on the same book.
  # Threads are one level deep - replying to a reply joins the same thread.
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, -> { order(:created_at) },
           class_name: "Comment", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :destroy

  scope :top_level, -> { where(parent_id: nil) }

  normalizes :body, with: ->(body) { body.strip }

  before_validation :join_parent_thread

  validates :body, presence: true, length: { maximum: 2000 }
  validate :parent_is_on_the_same_book

  def reply?
    parent_id.present?
  end

  # The comment whose thread this belongs to (itself, for top-level comments).
  def thread_root
    parent || self
  end

  # The person who wrote the comment can delete it, and so can admins.
  def deletable_by?(someone)
    someone.present? && (user_id == someone.id || someone.admin?)
  end

  private
    def join_parent_thread
      self.parent = parent.parent if parent&.parent
    end

    def parent_is_on_the_same_book
      return if parent_id.blank?

      if parent.nil? || parent.book_id != book_id
        errors.add(:parent, "must be a comment on this book")
      end
    end
end
