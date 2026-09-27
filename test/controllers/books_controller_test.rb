require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:hobbit)          # belongs to users(:one)
    @someone_elses_book = books(:dune) # belongs to users(:two)
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

  test "a new book belongs to the signed-in user" do
    post books_url, params: { book: { title: "Emma", author: "Jane Austen" } }
    assert_equal users(:one), Book.last.user
  end

  test "cannot create a book on behalf of someone else" do
    post books_url, params: { book: { title: "Emma", author: "Jane Austen", user_id: users(:two).id } }
    assert_equal users(:one), Book.last.user
  end

  test "should save subtitle and review" do
    post books_url, params: { book: { title: "Dune", subtitle: "Book One", author: "Frank Herbert", review: "Loved the worldbuilding." } }

    book = Book.last
    assert_equal "Book One", book.subtitle
    assert_equal "Loved the worldbuilding.", book.review
  end

  test "should add a review to an existing book" do
    patch book_url(@book), params: { book: { review: "Slow start, brilliant ending." } }

    assert_equal "Slow start, brilliant ending.", @book.reload.review
  end

  test "show displays the subtitle and review" do
    get book_url(@book)
    assert_select ".book-subtitle", "There and Back Again"
    assert_select ".book-review-text", /cosy adventure/
  end

  test "show invites the owner to write a review when there is none" do
    @book.update!(review: nil)
    get book_url(@book)
    assert_select ".book-review h2", "My review"
    assert_select ".book-review a", "Write your review"
  end

  test "show lets the owner edit and delete" do
    get book_url(@book)
    assert_select ".pill", /Added by you/
    assert_select "a", "Edit book"
    assert_select "button", "Delete book"
  end

  test "show hides edit and delete from other users" do
    get book_url(@someone_elses_book)
    assert_response :success
    assert_select ".pill", /Added by Bob Bookworm/
    assert_select ".book-review h2", "Bob Bookworm's review"
    assert_select "a", text: "Edit book", count: 0
    assert_select "button", text: "Delete book", count: 0
    assert_select "a", text: "Write your review", count: 0
  end

  test "the book form can offer a book for exchange" do
    patch book_url(@book), params: { book: { available_for_exchange: "1" } }
    assert @book.reload.available_for_exchange?

    patch book_url(@book), params: { book: { available_for_exchange: "0" } }
    assert_not @book.reload.available_for_exchange?
  end

  test "books offered for exchange show a badge on their cover" do
    get books_url
    assert_select "#book_#{@someone_elses_book.id} .exchange-badge", "For exchange"
    assert_select "#book_#{@book.id} .exchange-badge", count: 0
  end

  test "the form has ISBN and cover fields" do
    get new_book_url
    assert_select "input[name=?]", "book[isbn]"
    assert_select "input[type=file][name=?]", "book[cover]"
    assert_select "input[type=hidden][name=?]", "book[open_library_cover_id]"
    assert_select "button", "Find cover online"
  end

  test "create a book with an ISBN and an uploaded cover" do
    post books_url, params: { book: {
      title: "Piranesi", author: "Susanna Clarke", isbn: "978-1-63557-563-7",
      cover: fixture_file_upload("cover.jpg", "image/jpeg")
    } }

    book = Book.last
    assert_redirected_to book_url(book)
    assert_equal "9781635575637", book.isbn
    assert book.cover_ready?
  end

  test "create a book with a cover picked online" do
    fake_open_library "covers.openlibrary.org/b/id/42-L.jpg" => open_library_image

    post books_url, params: { book: { title: "Piranesi", author: "Susanna Clarke", open_library_cover_id: "42" } }

    assert Book.last.cover_ready?
  end

  test "an invalid ISBN shows an error" do
    assert_no_difference("Book.count") do
      post books_url, params: { book: { title: "Piranesi", author: "Susanna Clarke", isbn: "123" } }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /Isbn isn't a valid ISBN/
  end

  test "books with a cover show the image; others show the generated cover" do
    @book.cover.attach(fixture_file_upload("cover.jpg", "image/jpeg"))

    get books_url
    assert_select "#book_#{@book.id} .book-cover-image img"
    assert_select "#book_#{@someone_elses_book.id} .book-cover-title", "Dune"

    get book_url(@book)
    assert_select ".book-detail .book-cover-image img"
  end

  test "the book page shows the ISBN" do
    @book.update!(isbn: "9780547928227")
    get book_url(@book)
    assert_select ".pill", "ISBN 9780547928227"
  end

  test "the edit form offers to remove an existing cover" do
    @book.cover.attach(fixture_file_upload("cover.jpg", "image/jpeg"))
    get edit_book_url(@book)
    assert_select "input[type=checkbox][name=?]", "book[remove_cover]"

    patch book_url(@book), params: { book: { remove_cover: "1" } }
    assert_not @book.reload.cover.attached?
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

  test "cannot open the edit page for someone else's book" do
    get edit_book_url(@someone_elses_book)
    assert_redirected_to book_url(@someone_elses_book)
    follow_redirect!
    assert_select ".flash-alert", /Only the person who added this book/
  end

  test "cannot update someone else's book" do
    patch book_url(@someone_elses_book), params: { book: { title: "Hacked", review: "Not mine to write" } }

    assert_redirected_to book_url(@someone_elses_book)
    @someone_elses_book.reload
    assert_equal "Dune", @someone_elses_book.title
    assert_nil @someone_elses_book.review
  end

  test "cannot delete someone else's book" do
    assert_no_difference("Book.count") do
      delete book_url(@someone_elses_book)
    end
    assert_redirected_to book_url(@someone_elses_book)
  end

  test "an admin can edit someone else's book" do
    sign_out
    sign_in_as users(:admin)

    get edit_book_url(@someone_elses_book)
    assert_response :success

    patch book_url(@someone_elses_book), params: { book: { title: "Dune (Revised)" } }
    assert_redirected_to book_url(@someone_elses_book)
    assert_equal "Dune (Revised)", @someone_elses_book.reload.title
  end

  test "an admin can delete someone else's book" do
    sign_out
    sign_in_as users(:admin)

    assert_difference("Book.count", -1) do
      delete book_url(@someone_elses_book)
    end
  end

  test "an admin sees edit controls and a note on someone else's book" do
    sign_out
    sign_in_as users(:admin)

    get book_url(@someone_elses_book)
    assert_select "a", "Edit book"
    assert_select ".admin-note", /You're an admin/
    assert_select ".book-review h2", "Bob Bookworm's review"
    assert_select "a", text: "Write your review", count: 0
  end

  test "the admin badge shows only for admins" do
    get books_url
    assert_select ".badge", count: 0

    sign_out
    sign_in_as users(:admin)
    get books_url
    assert_select ".nav-user .badge", "Admin"
  end

  test "should destroy book" do
    assert_difference("Book.count", -1) do
      delete book_url(@book)
    end

    assert_redirected_to books_url
  end
end
