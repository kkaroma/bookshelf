# A book a member would like: "tell me when someone offers it for exchange".
# Matches a book by ISBN, or by title (and author, if given), ignoring capitals.
class WishlistItem < ApplicationRecord
  belongs_to :user

  normalizes :title, with: ->(title) { title.squish }
  normalizes :author, with: ->(author) { author.squish.presence }
  normalizes :isbn, with: ->(isbn) { isbn.upcase.gsub(/[^0-9X]/, "").presence }

  validates :title, presence: true, length: { maximum: 200 }
  validates :author, length: { maximum: 100 }
  validate :isbn_is_valid, if: -> { isbn.present? }

  # Wishlist entries (of other members) that this book would satisfy.
  scope :matching, ->(book) {
    where.not(user_id: book.user_id).where(<<~SQL, isbn: book.isbn, title: book.title, author: book.author)
      (wishlist_items.isbn IS NOT NULL AND wishlist_items.isbn = :isbn)
      OR (LOWER(wishlist_items.title) = LOWER(:title)
          AND (wishlist_items.author IS NULL OR LOWER(wishlist_items.author) = LOWER(:author)))
    SQL
  }

  # Books on the Exchange shelf right now that match this entry.
  def available_books
    books = Book.for_exchange.where.not(user_id: user_id).includes(:user)
    title_match = books.where("LOWER(books.title) = LOWER(?)", title)
    title_match = title_match.where("LOWER(books.author) = LOWER(?)", author) if author
    isbn ? books.where(isbn: isbn).or(title_match) : title_match
  end

  # Is this the same book? (Used to show "On your wishlist" on a book page.)
  def matches?(book)
    return book.isbn == isbn if isbn && book.isbn
    title.casecmp?(book.title) && (author.nil? || author.casecmp?(book.author.to_s))
  end

  private
    def isbn_is_valid
      errors.add(:isbn, "isn't a valid ISBN (check for typos)") unless Book.valid_isbn?(isbn)
    end
end
