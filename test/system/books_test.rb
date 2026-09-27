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

  test "rating a book with stars" do
    visit book_path(books(:dune)) # Bob's book, not yet rated
    assert_text "No ratings yet"

    click_on "Rate 4 stars"
    assert_selector ".rating-average", text: "4.0"
    assert_text "1 rating"
    assert_selector ".star-on", count: 4
    assert_current_path book_path(books(:dune)) # stayed on the page

    click_on "Rate 2 stars" # change my mind
    assert_selector ".rating-average", text: "2.0"
    assert_text "1 rating"

    click_on "Remove"
    assert_text "No ratings yet"
  end

  test "you cannot rate your own book" do
    visit book_path(books(:hobbit)) # Alice's own book
    assert_text "You can't rate your own book"
    assert_no_button "Rate 5 stars"
  end

  test "offering a book for exchange puts it on the Exchange shelf" do
    visit book_path(books(:hobbit)) # Alice's own book
    click_on "Offer for exchange"
    assert_text "is now on the Exchange shelf"
    assert_text "Available for exchange"

    click_on "Exchange shelf"
    assert_selector "h1", text: "Exchange shelf"
    assert_selector ".book-card", text: "The Hobbit"
    assert_selector ".book-card", text: "Dune"

    click_on "The Hobbit", match: :first
    click_on "Remove from exchange"
    assert_text "was removed from the Exchange shelf"

    click_on "Exchange shelf"
    assert_no_selector ".book-card", text: "The Hobbit"
  end

  test "following and unfollowing a member" do
    click_on "Members"
    assert_selector "h1", text: "Members"

    within "#user_#{users(:admin).id}" do
      assert_text "0 followers"
      click_on "Follow Ada Admin"
      assert_text "1 follower"
      assert_button "Unfollow Ada Admin"
    end
    assert_current_path users_path # stayed on the page

    click_link "Ada Admin"
    assert_selector "h1", text: "Ada Admin"
    click_on "1 follower"
    assert_selector "h1", text: "Followers"
    assert_selector ".member", text: "Alice Reader"

    click_on "Members"
    within "#user_#{users(:admin).id}" do
      click_on "Unfollow Ada Admin"
      assert_text "0 followers"
    end
  end

  test "clicking a comment author opens their profile" do
    visit book_path(books(:hobbit))
    click_on "Bob Bookworm", match: :first
    assert_selector "h1", text: "Bob Bookworm"
    assert_selector ".section-title", text: "Bob Bookworm's books"
  end

  test "requesting a book and the owner accepting it" do
    # Alice asks Bob for Dune, offering The Hobbit
    visit book_path(books(:dune))
    click_on "Request exchange"
    select "The Hobbit", from: "Offer one of your books in return"
    fill_in "Message", with: "Would you swap for The Hobbit?"
    click_on "Send request"

    assert_text "Request sent!"
    assert_selector ".tab.active", text: "Sent"
    assert_selector ".request", text: "You asked Bob Bookworm for Dune"
    assert_selector ".status", text: "PENDING"

    # Bob signs in, sees the badge, and accepts
    click_on "Sign out"
    assert_text "You have been signed out."
    sign_in_as users(:two)
    assert_selector ".nav-count", text: "2" # Alice's request and the admin's

    click_on "Requests"
    within ".request", text: "Alice Reader would like your book" do
      accept_confirm { click_on "Accept" }
    end

    assert_text "You accepted Alice Reader's request"
    within ".request", text: "Alice Reader would like your book" do
      assert_selector ".status", text: "ACCEPTED"
      assert_link "one@example.com"
    end
    # The other request for Dune was declined automatically
    assert_selector ".request", text: "Ada Admin would like your book", visible: true
    assert_selector ".request-declined .status", text: "DECLINED"
    assert_no_selector ".nav-count"

    # Dune is no longer on the Exchange shelf
    click_on "Exchange shelf"
    assert_no_selector ".book-card", text: "Dune"
  end

  test "adding a book with a cover found online" do
    fake_open_library(
      "search.json" => open_library_json([
        { "title" => "Piranesi", "author_name" => [ "Susanna Clarke" ], "cover_i" => 555,
          "first_publish_year" => 2020, "isbn" => [ "9781635575637" ] }
      ]),
      "covers.openlibrary.org/b/id/555-L.jpg" => open_library_image
    )

    click_on "Add a book", match: :first
    fill_in "Title", with: "Piranesi"
    fill_in "Author", with: "Susanna Clarke"
    click_on "Find cover online"

    click_on "Use cover: Piranesi, 2020"
    assert_selector ".cover-result[aria-pressed='true']"
    assert_selector ".cover-preview img"
    assert_field "ISBN", with: "9781635575637" # filled in from the result

    click_on "Create Book"
    assert_text "Book was successfully created."
    assert_selector ".book-detail .book-cover-image img"
    assert_text "ISBN 9781635575637"
  end

  test "uploading a cover from your computer" do
    visit edit_book_path(books(:hobbit))
    attach_file "Upload image", file_fixture("cover.png"), make_visible: true
    assert_selector ".cover-preview img"

    click_on "Update Book"
    assert_selector ".book-detail .book-cover-image img"

    visit books_path
    assert_selector "#book_#{books(:hobbit).id} .book-cover-image img"
  end
end
