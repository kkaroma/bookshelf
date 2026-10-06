# Lending one of your books to someone: who has it, since when, when it's due
# back, and when it came back. Only the book's owner sees loans.
class Loan < ApplicationRecord
  belongs_to :book

  # Loans that haven't come back yet ("outstanding") and ones that have.
  scope :outstanding, -> { where(returned_on: nil) }
  scope :returned, -> { where.not(returned_on: nil) }

  normalizes :borrower_name, with: ->(name) { name.squish }
  normalizes :note, with: ->(note) { note.strip.presence }

  validates :borrower_name, presence: true, length: { maximum: 100 }
  validates :lent_on, presence: true
  validates :note, length: { maximum: 500 }
  validate :dates_make_sense
  validate :book_not_already_lent_out, on: :create

  def outstanding? = returned_on.nil?

  def overdue?(today = Date.current)
    outstanding? && due_on.present? && due_on < today
  end

  def return!(on: Date.current)
    update!(returned_on: on)
  end

  private
    def dates_make_sense
      return if lent_on.blank?

      errors.add(:lent_on, "can't be in the future") if lent_on > Date.current
      errors.add(:due_on, "can't be before the day you lent it") if due_on && due_on < lent_on
      errors.add(:returned_on, "can't be before the day you lent it") if returned_on && returned_on < lent_on
    end

    def book_not_already_lent_out
      if book && book.loans.outstanding.where.not(id: id).exists?
        errors.add(:base, "This book is already lent out - mark it as returned first")
      end
    end
end
