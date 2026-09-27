require "test_helper"

class ExchangesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) } # Alice

  test "lists only books offered for exchange" do
    get exchanges_url

    assert_response :success
    assert_select "h1", "Exchange shelf"
    assert_select "#books .book-card", 1
    assert_select "#book_#{books(:dune).id}"
    assert_select "#book_#{books(:hobbit).id}", count: 0
  end

  test "says how many of the listed books are yours" do
    books(:hobbit).update!(available_for_exchange: true)
    get exchanges_url

    assert_select ".page-header p", /2 books members are happy to swap/
    assert_select ".page-header p", /One of them is yours/
  end

  test "shows a friendly message when the shelf is empty" do
    Book.update_all(available_for_exchange: false)
    get exchanges_url

    assert_select ".empty-state h2", "Nothing on the shelf yet"
    assert_select "#books", count: 0
  end

  test "the header links to the exchange shelf and highlights it" do
    get exchanges_url
    assert_select ".nav-main a.active", "Exchange shelf"

    get books_url
    assert_select ".nav-main a.active", "Books"
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get exchanges_url
    assert_redirected_to new_session_url
  end
end
