require "test_helper"

class Books::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:hobbit)              # belongs to users(:one)
    @someone_elses_book = books(:dune)  # belongs to users(:two), no review
    sign_in_as users(:one)
  end

  test "book page links to the review form when there is no review" do
    @book.update!(review: nil)
    get book_url(@book)
    assert_select ".book-review a[href=?]", edit_book_review_path(@book), text: "Write your review"
  end

  test "book page links to edit an existing review" do
    get book_url(@book)
    assert_select ".book-review a[href=?]", edit_book_review_path(@book), text: "Edit review"
  end

  test "edit shows the review form" do
    get edit_book_review_url(@book)
    assert_response :success
    assert_select "turbo-frame[id=?]", dom_id(@book, :review)
    assert_select "textarea[name=?]", "book[review]"
  end

  test "update saves the review and returns to the book" do
    patch book_review_url(@book), params: { book: { review: "Even better the second time." } }

    assert_redirected_to book_url(@book)
    assert_equal "Even better the second time.", @book.reload.review
  end

  test "update only changes the review, not other fields" do
    patch book_review_url(@book), params: { book: { review: "Great.", title: "Sneaky new title" } }

    assert_equal "The Hobbit", @book.reload.title
    assert_equal "Great.", @book.review
  end

  test "saving a blank review removes it" do
    patch book_review_url(@book), params: { book: { review: "   " } }
    assert_nil @book.reload.review
  end

  test "other users cannot open the review form" do
    get edit_book_review_url(@someone_elses_book)
    assert_redirected_to book_url(@someone_elses_book)
  end

  test "other users cannot write the review" do
    patch book_review_url(@someone_elses_book), params: { book: { review: "Not my book" } }

    assert_redirected_to book_url(@someone_elses_book)
    assert_nil @someone_elses_book.reload.review
  end

  test "other users do not see the review links" do
    get book_url(@someone_elses_book)
    assert_select "a", text: "Write your review", count: 0
    assert_select "a", text: "Edit review", count: 0
  end

  test "an admin can update the review" do
    sign_out
    sign_in_as users(:admin)

    patch book_review_url(@someone_elses_book), params: { book: { review: "Fixed a typo." } }
    assert_equal "Fixed a typo.", @someone_elses_book.reload.review
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get edit_book_review_url(@book)
    assert_redirected_to new_session_url
  end
end
