require "application_system_test_case"

class GenresTest < ApplicationSystemTestCase
  test "an admin adds and renames a genre, and members can choose it" do
    sign_in_as users(:admin)
    visit admin_genres_path
    fill_in "New genre", with: "Swahili literture"
    click_on "Add genre"
    assert_text "Added “Swahili literture”."

    within(".genre-row:last-child") do
      fill_in "Name of Swahili literture", with: "Swahili literature" # fix the typo
      click_on "Rename"
    end
    assert_text "Renamed “Swahili literture” to “Swahili literature”."
    click_on "Sign out"

    sign_in_as users(:one)
    visit edit_book_path(books(:hobbit))
    select "Swahili literature", from: "Genre"
    click_on "Update Book"
    assert_text "Book was successfully updated."
    assert_selector ".pill", text: "Swahili literature"
  end
end
