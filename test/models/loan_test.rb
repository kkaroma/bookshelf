require "test_helper"

class LoanTest < ActiveSupport::TestCase
  setup { @hobbit = books(:hobbit) }

  def lend(**attributes)
    @hobbit.loans.create!({ borrower_name: "Bob", lent_on: Date.new(2026, 9, 1) }.merge(attributes))
  end

  test "a loan needs a borrower and a date" do
    assert_not @hobbit.loans.new(lent_on: Date.current).valid?
    assert_not @hobbit.loans.new(borrower_name: "Bob").valid?
  end

  test "dates must make sense" do
    assert_not @hobbit.loans.new(borrower_name: "Bob", lent_on: Date.current + 1).valid?
    loan = @hobbit.loans.new(borrower_name: "Bob", lent_on: Date.new(2026, 9, 10), due_on: Date.new(2026, 9, 1))
    assert_not loan.valid?
    assert_includes loan.errors[:due_on], "can't be before the day you lent it"
  end

  test "a book can only be lent to one person at a time" do
    lend
    second = @hobbit.loans.new(borrower_name: "Ada", lent_on: Date.current)
    assert_not second.valid?
    assert_match "already lent out", second.errors.full_messages.first
  end

  test "the database also refuses a second outstanding loan" do
    lend
    assert_raises(ActiveRecord::RecordNotUnique) do
      Loan.insert!({ book_id: @hobbit.id, borrower_name: "Ada", lent_on: Date.current })
    end
  end

  test "returning a loan, then lending again" do
    loan = lend
    assert_equal loan, @hobbit.current_loan

    loan.return!(on: Date.new(2026, 9, 20))
    assert_nil @hobbit.current_loan
    assert_not loan.outstanding?

    assert lend(borrower_name: "Ada", lent_on: Date.new(2026, 9, 21)).persisted?
  end

  test "overdue means not back and past the due date" do
    loan = lend(due_on: Date.new(2026, 9, 30))
    assert_not loan.overdue?(Date.new(2026, 9, 30))
    assert loan.overdue?(Date.new(2026, 10, 1))

    loan.return!(on: Date.new(2026, 10, 2))
    assert_not loan.overdue?(Date.new(2026, 10, 5))

    assert_not lend(borrower_name: "Ada", lent_on: Date.new(2026, 10, 3)).overdue? # no due date
  end

  test "deleting a book deletes its loans" do
    lend
    assert_difference("Loan.count", -1) { @hobbit.destroy }
  end
end
