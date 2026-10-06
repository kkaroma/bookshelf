require "test_helper"

class Books::LoansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hobbit = books(:hobbit) # Alice's
    sign_in_as users(:one)
  end

  test "lend your book, then mark it returned" do
    post book_loans_url(@hobbit), params: { loan: { borrower_name: "Bob", lent_on: Date.current, due_on: Date.current + 14 } }
    assert_redirected_to book_url(@hobbit)
    loan = @hobbit.current_loan
    assert_equal "Bob", loan.borrower_name

    patch return_book_loan_url(@hobbit, loan)
    assert_equal Date.current, loan.reload.returned_on
    assert_nil @hobbit.current_loan
  end

  test "problems are explained" do
    post book_loans_url(@hobbit), params: { loan: { borrower_name: "", lent_on: Date.current } }
    assert_nil @hobbit.current_loan
    follow_redirect!
    assert_select ".flash-alert", /Borrower name can't be blank/
  end

  test "only the owner can lend or see lending - not other members, not even admins" do
    post book_loans_url(books(:dune)), params: { loan: { borrower_name: "Me", lent_on: Date.current } } # Bob's book
    assert_response :not_found

    @hobbit.loans.create!(borrower_name: "Secret Sam", lent_on: Date.current)
    sign_out
    sign_in_as users(:admin)
    get book_url(@hobbit)
    assert_select ".lending", count: 0
    assert_no_match "Secret Sam", response.body
  end

  test "the book page shows the current loan, overdue in red, and history" do
    @hobbit.loans.create!(borrower_name: "Ada", lent_on: Date.current - 40, returned_on: Date.current - 30)
    @hobbit.loans.create!(borrower_name: "Bob", lent_on: Date.current - 20, due_on: Date.current - 1)

    get book_url(@hobbit)
    assert_select ".loan-current.is-overdue", /Lent to\s+Bob/
    assert_select ".overdue-tag", "Overdue"
    assert_select "button", "Mark as returned"
    assert_select ".loan-history li", /Ada/
  end

  test "lent-out books are flagged on your cards and listed on Home" do
    @hobbit.loans.create!(borrower_name: "Bob", lent_on: Date.current)

    get user_url(users(:one))
    assert_select "#book_#{@hobbit.id} .status-lent", "Lent out"

    get root_url
    assert_select "#lent_out li", /The Hobbit\s+— Bob/
  end
end
