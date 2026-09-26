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

    click_on "Write your review"
    fill_in "My review", with: "Strange, gentle and beautiful."
    fill_in "Title", with: "Piranesi (Hardback)"
    click_on "Update Book"
    assert_selector "h1", text: "Piranesi (Hardback)"
    assert_selector ".book-review-text", text: "Strange, gentle and beautiful."

    accept_confirm { click_on "Delete book" }
    assert_text "Book was successfully destroyed."
    assert_no_text "Piranesi"
  end
end
