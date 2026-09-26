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
