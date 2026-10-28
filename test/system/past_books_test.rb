require "application_system_test_case"

class PastBooksTest < ApplicationSystemTestCase
  test "after a swap, Alice's review and its comments stay on her profile" do
    hobbit = books(:hobbit) # Alice's, reviewed, with Bob's comment
    hobbit.update!(available_for_exchange: true)
    swap = ExchangeRequest.create!(requester: users(:two), book: hobbit)
    swap.accept!

    sign_in_as users(:one)
    visit exchange_request_path(swap)
    accept_confirm { click_on "Mark swap as done" }
    assert_text "Swap done!"

    # A follower opens Alice's profile: the Hobbit is under "Books Alice has had".
    click_on "Sign out"
    sign_in_as users(:admin)
    visit user_path(users(:one))
    within("#past_books") do
      assert_text "Swapped to Bob Bookworm"
      click_on "The Hobbit"
    end
    assert_selector ".given-away-note", text: "swapped this book to Bob Bookworm"
    assert_selector ".book-review-text", text: "cosy adventure"
    within("#comments") { assert_text comments(:bob_on_hobbit).body }

    # ...and Bob's own copy starts fresh.
    click_on "See Bob's copy →"
    assert_selector ".given-away-note", text: "Came to Bob Bookworm from Alice Reader in a swap"
    within("#comments") { assert_no_text comments(:bob_on_hobbit).body }
  end

  test "I no longer have it moves a book to Books I've had" do
    sign_in_as users(:one)
    visit book_path(books(:hobbit))
    accept_confirm { click_on "I no longer have it" }
    assert_text "moved to Books I've had"

    visit user_path(users(:one))
    within("#past_books") { assert_text "The Hobbit" }
    within(".profile-stats") { assert_text "0 books" }
  end
end
