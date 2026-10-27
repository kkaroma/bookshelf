require "application_system_test_case"

class ReportsTest < ApplicationSystemTestCase
  test "an admin explores the Swaps and Member journey reports" do
    WishlistItem.create!(user: users(:one), title: "Middlemarch", author: "George Eliot")
    sign_in_as users(:admin)

    within(".nav-main") { click_on "Admin" }
    within(".tabs") { click_on "Swaps" }
    assert_selector ".stat-tile", text: "Requests made"
    within("#most_wanted") { assert_text "Middlemarch" }
    click_on "All time"
    assert_selector ".period-choice.active", text: "All time"
    assert_current_path admin_swaps_path(period: "all")

    within(".tabs") { click_on "Member journey" }
    assert_selector ".funnel-step", count: 5
    assert_selector "#step_joined", text: "Signed up"
  end

  test "a member opens their year in books from Home" do
    Book.create!(user: users(:one), title: "Emma", author: "Jane Austen", genre: "Fiction",
                 reading_status: :read, finished_on: Date.current)
    sign_in_as users(:one)

    click_on "My year in books"
    assert_selector "h1", text: "My #{Date.current.year} in books"
    assert_selector "#books_read_count", text: "1"
    within("#books") { assert_text "Emma" }
  end
end
