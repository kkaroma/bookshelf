require "test_helper"

# Books leaving a shelf without disappearing ("Books I've had").
class PastBooksTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @hobbit = books(:hobbit) # Alice's, with a review and comments
  end

  test "I no longer have it: off the shelf, review and comments kept" do
    @hobbit.give_away!

    assert @hobbit.given_away?
    assert_nil @hobbit.given_to
    assert_includes @alice.past_books, @hobbit
    assert_not_includes @alice.books.on_shelf, @hobbit
    assert_equal 0, @alice.reload.books_count
    assert @hobbit.reload.review.present?
    assert @hobbit.comments.any?
  end

  test "giving away a book closes an outstanding loan and unlists it" do
    @hobbit.update!(available_for_exchange: true)
    @hobbit.loans.create!(borrower_name: "Sam", lent_on: Date.current)

    @hobbit.give_away!
    assert_nil @hobbit.current_loan
    assert_not @hobbit.available_for_exchange?
  end

  test "a book you no longer have can't be offered or lent" do
    @hobbit.give_away!

    assert_not @hobbit.update(available_for_exchange: true)
    assert_includes @hobbit.errors.full_messages, "Available for exchange isn't possible for a book you no longer have"

    loan = @hobbit.loans.build(borrower_name: "Sam", lent_on: Date.current)
    assert_not loan.valid?
    assert_not @hobbit.lendable_by?(@alice)
  end

  test "putting it back on the shelf" do
    @hobbit.give_away!
    @hobbit.put_back_on_shelf!

    assert_not @hobbit.given_away?
    assert_equal 1, @alice.reload.books_count
  end

  test "a swapped book can't be put back - the other person has their copy" do
    copy = @hobbit.hand_over_to!(users(:two))
    assert_raises(ArgumentError) { @hobbit.put_back_on_shelf! }
    assert_equal users(:two), copy.user
  end

  test "deleting the new owner's copy leaves the old one, and the other way round" do
    copy = @hobbit.hand_over_to!(users(:two))

    copy.destroy!
    assert_nil @hobbit.reload.successor
    assert @hobbit.persisted?

    other = books(:dune).hand_over_to!(@alice)
    books(:dune).destroy!
    assert_nil other.reload.predecessor
  end

  test "deleting your account deletes the books you've had too" do
    @hobbit.give_away!
    assert_difference("Book.count", -1) { @alice.destroy! }
  end
end
