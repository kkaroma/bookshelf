require "test_helper"

class Books::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @hobbit = books(:hobbit)
    sign_in_as @alice
  end

  test "the owner sees “I no longer have it” and a clearer delete warning" do
    get book_url(@hobbit)
    assert_select "form[action=?] button", book_removal_path(@hobbit), "I no longer have it"
    assert_select "form[action=?][data-turbo-confirm*=?]", book_path(@hobbit), "I no longer have it"
  end

  test "I no longer have it, then put it back" do
    post book_removal_url(@hobbit)
    assert @hobbit.reload.given_away?
    assert_redirected_to book_url(@hobbit)
    assert_match(/moved to Books I've had/, flash[:notice])

    get book_url(@hobbit)
    assert_select ".given-away-note", /You no longer have this book/
    assert_select "button", text: "Offer for exchange", count: 0
    assert_select "button", "Put back on my shelf"
    assert_select ".book-review", /cosy adventure/ # the review stays

    delete book_removal_url(@hobbit)
    assert_not @hobbit.reload.given_away?
  end

  test "only the owner can do it - not other members or admins" do
    sign_out
    sign_in_as users(:admin)
    post book_removal_url(@hobbit)
    assert_response :not_found
    assert_not @hobbit.reload.given_away?
  end

  test "a swapped book can't be put back" do
    @hobbit.hand_over_to!(users(:two))
    get book_url(@hobbit)
    assert_select "button", text: "Put back on my shelf", count: 0

    delete book_removal_url(@hobbit)
    assert @hobbit.reload.given_away?
    assert_match(/went to someone in a swap/, flash[:alert])
  end

  test "offering a given-away book for exchange is refused politely" do
    @hobbit.give_away!
    post book_exchange_listing_url(@hobbit)
    assert_match(/isn't possible for a book you no longer have/, flash[:alert])
  end
end
