# A genre members can give their books, managed by admins at /admin/genres.
# Books store the genre's name (books.genre), so renaming a genre updates
# every book that has it. A genre still in use can't be deleted - retire it
# instead: it's hidden from new choices but stays on the books that have it.
class Genre < ApplicationRecord
  # What a brand-new site starts with (db/seeds.rb); admins change it from there.
  STARTING_NAMES = [
    "Fiction", "Fantasy", "Science fiction", "Mystery & thriller", "Romance",
    "Historical fiction", "Children's", "Young adult", "Poetry",
    "Non-fiction", "Biography & memoir", "History", "Science & nature",
    "Business & money", "Self-help", "Religion & spirituality", "Cookery",
    "Art & design", "Other"
  ].freeze

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(retired_at: nil) }

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 40 },
                   uniqueness: { case_sensitive: false, message: "already exists" }

  before_create :go_to_the_end
  after_update :rename_on_books, if: :saved_change_to_name?
  before_destroy :only_if_unused

  # Every genre name, in order (retired ones too - books may still have them).
  def self.names = ordered.pluck(:name)

  # What the book form offers: genres in use now, plus the book's own genre
  # if that has since been retired (so saving the form doesn't lose it).
  def self.choices_for(book)
    choices = active.ordered.pluck(:name)
    book.genre.present? && !choices.include?(book.genre) ? choices + [ book.genre ] : choices
  end

  def books = Book.where(genre: name)

  def retired? = retired_at.present?
  def retire! = update!(retired_at: Time.current)
  def restore! = update!(retired_at: nil)

  # Swap places with the genre above ("up") or below ("down").
  def move!(direction)
    neighbour = direction.to_s == "up" ? Genre.ordered.where(position: ...position).last : Genre.ordered.where(position: (position + 1)..).first
    return unless neighbour

    transaction do
      mine = position
      update_columns(position: neighbour.position)
      neighbour.update_columns(position: mine)
    end
  end

  private
    def go_to_the_end
      self.position = (Genre.maximum(:position) || 0) + 1
    end

    def rename_on_books
      Book.where(genre: name_before_last_save).update_all(genre: name, updated_at: Time.current)
    end

    def only_if_unused
      return unless books.exists?

      errors.add(:base, "#{name} is used by #{books.count} #{"book".pluralize(books.count)}. Retire it instead.")
      throw :abort
    end
end
