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

  test "the exchange shelf is split into pages" do
    25.times { |i| Book.create!(user: users(:two), title: "Swap #{i}", author: "A", available_for_exchange: true) }

    get exchanges_url
    assert_select "#books .book-card", 24
    assert_select ".page-header p", /26 books members are happy to swap/
    assert_select ".pagination", /Page 1 of 2/
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

  test "without a town, the shelf suggests adding one" do
    get exchanges_url
    assert_select ".near-me a[href=?]", edit_settings_profile_path, text: "Add your town"
  end

  test "books from your own town come first, and you can show only those" do
    users(:one).update!(city: "Dar es Salaam")
    users(:admin).update!(city: "dar es salaam")
    users(:two).update!(city: "Arusha")
    near = Book.create!(user: users(:admin), title: "Nearby Book", author: "A", available_for_exchange: true, updated_at: 1.year.ago)

    get exchanges_url
    assert_select ".near-me", /Books in\s+Dar es Salaam\s+are shown first/
    assert_select "#books .book-card:first-child .book-card-title", "Nearby Book" # first despite being older
    assert_select "#book_#{near.id} .same-town", "📍 dar es salaam"
    assert_select "#book_#{books(:dune).id} .book-card-owner", /Arusha/

    get exchanges_url(near: 1)
    assert_select "#books .book-card", 1
    assert_select ".near-me a", "Show books everywhere"
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get exchanges_url
    assert_redirected_to new_session_url
  end
end
