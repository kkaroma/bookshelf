require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:hobbit)
    sign_in_as users(:one)
  end

  test "redirects to sign in when not signed in" do
    sign_out
    get books_url
    assert_redirected_to new_session_url
  end

  test "should get index" do
    get books_url
    assert_response :success
  end

  test "should get new" do
    get new_book_url
    assert_response :success
  end

  test "should create book" do
    assert_difference("Book.count") do
      post books_url, params: { book: { author: @book.author, description: @book.description, published_year: @book.published_year, title: @book.title } }
    end

    assert_redirected_to book_url(Book.last)
  end

  test "should save subtitle and review" do
    post books_url, params: { book: { title: "Dune", subtitle: "Book One", author: "Frank Herbert", review: "Loved the worldbuilding." } }

    book = Book.last
    assert_equal "Book One", book.subtitle
    assert_equal "Loved the worldbuilding.", book.review
  end

  test "should add a review to an existing book" do
    book = books(:dune)
    patch book_url(book), params: { book: { review: "Slow start, brilliant ending." } }

    assert_equal "Slow start, brilliant ending.", book.reload.review
  end

  test "show displays the subtitle and review" do
    get book_url(@book)
    assert_select ".book-subtitle", "There and Back Again"
    assert_select ".book-review-text", /cosy adventure/
  end

  test "show invites the owner to write a review when there is none" do
    get book_url(books(:dune))
    assert_select ".book-review a", "Write your review"
  end

  test "should not create book without a title" do
    assert_no_difference("Book.count") do
      post books_url, params: { book: { title: "", author: "Someone" } }
    end

    assert_response :unprocessable_content
  end

  test "should show book" do
    get book_url(@book)
    assert_response :success
  end

  test "should get edit" do
    get edit_book_url(@book)
    assert_response :success
  end

  test "should update book" do
    patch book_url(@book), params: { book: { author: @book.author, description: @book.description, published_year: @book.published_year, title: @book.title } }
    assert_redirected_to book_url(@book)
  end

  test "should destroy book" do
    assert_difference("Book.count", -1) do
      delete book_url(@book)
    end

    assert_redirected_to books_url
  end
end
