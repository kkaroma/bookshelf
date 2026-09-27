require "test_helper"

class Books::ExchangeListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hobbit = books(:hobbit) # Alice's, not offered for exchange
    @dune = books(:dune)     # Bob's, offered for exchange
    sign_in_as users(:one)   # Alice
  end

  test "owner can offer their book for exchange" do
    post book_exchange_listing_url(@hobbit)

    assert_redirected_to book_url(@hobbit)
    assert @hobbit.reload.available_for_exchange?
    follow_redirect!
    assert_select ".flash-notice", /now on the Exchange shelf/
  end

  test "owner can take their book off the exchange shelf" do
    @hobbit.update!(available_for_exchange: true)
    delete book_exchange_listing_url(@hobbit)

    assert_redirected_to book_url(@hobbit)
    assert_not @hobbit.reload.available_for_exchange?
  end

  test "the owner sees the right button for the book's state" do
    get book_url(@hobbit)
    assert_select "button", "Offer for exchange"
    assert_select "button", text: "Remove from exchange", count: 0

    @hobbit.update!(available_for_exchange: true)
    get book_url(@hobbit)
    assert_select "button", "Remove from exchange"
    assert_select ".pill-exchange", /Available for exchange/
  end

  test "other users cannot change someone else's listing" do
    delete book_exchange_listing_url(@dune)

    assert_redirected_to book_url(@dune)
    assert @dune.reload.available_for_exchange?
  end

  test "other users see that a book is available but get no button" do
    get book_url(@dune)
    assert_select ".pill-exchange", /Available for exchange/
    assert_select "button", text: "Remove from exchange", count: 0
    assert_select "button", text: "Offer for exchange", count: 0
  end

  test "an admin can take any book off the shelf" do
    sign_out
    sign_in_as users(:admin)

    delete book_exchange_listing_url(@dune)
    assert_not @dune.reload.available_for_exchange?
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    post book_exchange_listing_url(@hobbit)

    assert_redirected_to new_session_url
    assert_not @hobbit.reload.available_for_exchange?
  end
end
