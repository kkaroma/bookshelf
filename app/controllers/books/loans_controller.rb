# Lending your own books: record a loan, and mark it returned. The book page
# shows this in a Turbo Frame, so only the Lending box refreshes.
class Books::LoansController < ApplicationController
  before_action :set_book

  def create
    loan = @book.loans.build(params.expect(loan: [ :borrower_name, :lent_on, :due_on, :note ]))
    if loan.save
      redirect_to @book
    else
      redirect_to @book, alert: loan.errors.full_messages.to_sentence
    end
  end

  def return
    @book.loans.outstanding.find(params.expect(:id)).return!
    redirect_to @book
  end

  private
    # Only your own books - not even admins see who borrowed what.
    def set_book
      @book = Current.user.books.find(params.expect(:book_id))
    end
end
