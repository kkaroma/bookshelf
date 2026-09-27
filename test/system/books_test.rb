require "application_system_test_case"

class BooksTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "adding, editing and deleting a book" do
    click_on "Add a book", match: :first
    fill_in "Title", with: "Piranesi"
    fill_in "Subtitle", with: "A Novel"
    fill_in "Author", with: "Susanna Clarke"
    fill_in "Published year", with: "2020"
    fill_in "Description", with: "A man lives in a house of endless halls."
    click_on "Create Book"

    assert_text "Book was successfully created."
    assert_selector "h1", text: "Piranesi"

    assert_selector ".book-subtitle", text: "A Novel"
    assert_text "No review yet"

    click_on "Edit book"
    fill_in "Title", with: "Piranesi (Hardback)"
    fill_in "My review", with: "Strange, gentle and beautiful."
    click_on "Update Book"
    assert_selector "h1", text: "Piranesi (Hardback)"
    assert_selector ".book-review-text", text: "Strange, gentle and beautiful."

    accept_confirm { click_on "Delete book" }
    assert_text "Book was successfully destroyed."
    assert_no_text "Piranesi"
  end

  test "viewing someone else's book is read-only" do
    visit book_path(books(:dune))

    assert_selector "h1", text: "Dune"
    assert_text "Added by Bob Bookworm"
    assert_no_link "Edit book"
    assert_no_button "Delete book"
  end

  test "an admin can edit anyone's book" do
    click_on "Sign out"
    assert_text "You have been signed out."
    sign_in_as users(:admin)
    assert_text "Admin"

    visit book_path(books(:dune))
    assert_text "You're an admin"
    click_on "Edit book"
    fill_in "Title", with: "Dune (Revised)"
    click_on "Update Book"

    assert_selector "h1", text: "Dune (Revised)"
  end

  test "writing and editing a review from the book page" do
    book = books(:hobbit)
    book.update!(review: nil)
    visit book_path(book)

    click_on "Write your review"
    # The form appears in place: we are still on the book page.
    assert_current_path book_path(book)
    fill_in "What did you think of it?", with: "A perfect comfort read."
    click_on "Save review"

    assert_selector ".book-review-text", text: "A perfect comfort read."
    assert_current_path book_path(book)

    click_on "Edit review"
    fill_in "What did you think of it?", with: "A perfect comfort read. Smaug steals the show."
    click_on "Save review"
    assert_selector ".book-review-text", text: "Smaug steals the show."

    click_on "Edit review"
    click_on "Cancel"
    assert_selector ".book-review-text", text: "Smaug steals the show."
    assert_no_field "What did you think of it?"
  end

  test "commenting on a book and deleting the comment" do
    visit book_path(books(:dune))
    assert_selector "#comments_count", text: "1"

    fill_in "Add a comment", with: "One of my all-time favourites."
    click_on "Post comment"

    # Appears without a page reload, and the form is cleared
    assert_selector ".comment", text: "One of my all-time favourites."
    assert_selector "#comments_count", text: "2"
    assert_field "Add a comment", with: ""

    within ".comment", text: "One of my all-time favourites." do
      accept_confirm { click_on "Delete" }
    end
    assert_no_text "One of my all-time favourites."
    assert_selector "#comments_count", text: "1"
  end

  test "empty comment list shows a friendly message" do
    visit book_path(books(:hobbit))
    assert_no_text "No comments yet"

    books(:hobbit).comments.destroy_all
    visit book_path(books(:hobbit))
    assert_text "No comments yet"
  end

  test "replying to a comment" do
    visit book_path(books(:hobbit))
    thread = find("#thread_comment_#{comments(:bob_on_hobbit).id}")

    within thread do
      assert_no_field "Your reply" # hidden until you click Reply

      within(".comment", text: "Loved your take") { click_on "Reply" }
      fill_in "Your reply", with: "The riddles are the best bit!"
      click_on "Post reply"

      assert_selector ".comment-reply", text: "The riddles are the best bit!"
      assert_no_field "Your reply" # form closes again after posting
    end
    assert_selector "#comments_count", text: "3"
  end

  test "replying to a reply mentions that person, and cancel closes the form" do
    visit book_path(books(:hobbit))

    within ".comment-reply", text: "that chapter is my favourite" do
      click_on "Reply"
    end
    assert_field "Your reply", with: "@Alice Reader "

    click_on "Cancel"
    assert_no_field "Your reply"
  end
end
