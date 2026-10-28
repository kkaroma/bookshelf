require "test_helper"

# Where books you've had show up (and where they don't).
class PastBooksPagesTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob = users(:two)
    @hobbit = books(:hobbit)
    @copy = @hobbit.hand_over_to!(@bob) # Alice swapped her Hobbit to Bob
  end

  test "everyone sees them on the profile, with the swap" do
    sign_in_as users(:admin)
    get user_url(@alice)

    assert_select "#past_books h2", "Books Alice has had"
    assert_select "#past_books #book_#{@hobbit.id} .status-gone", "Swapped to Bob Bookworm"
    assert_select "#books #book_#{@hobbit.id}", 0 # not among her current books
    assert_select ".profile-stats", /0\s+books/
  end

  test "your own profile says Books I've had" do
    sign_in_as @alice
    get user_url(@alice)
    assert_select "#past_books h2", "Books I've had"
  end

  test "the old copy keeps its review and links to the new one, and back" do
    sign_in_as users(:admin)
    get book_url(@hobbit)
    assert_select ".given-away-note", /Alice Reader swapped this book to\s+Bob Bookworm/
    assert_select ".given-away-note a[href=?]", book_path(@copy), "See Bob's copy →"
    assert_select ".book-review-text", /cosy adventure/
    assert_select ".exchange-panel", 0

    get book_url(@copy)
    assert_select ".given-away-note", /Came to Bob Bookworm from\s+Alice Reader in a swap/
    assert_select ".given-away-note a[href=?]", book_path(@hobbit)
  end

  test "the Books page and Home show only books people have now" do
    sign_in_as @bob
    get books_url
    assert_select "#book_#{@hobbit.id}", 0
    assert_select "#book_#{@copy.id}"

    sign_out
    get root_url # the visitors' page: Alice's old copy isn't listed, and a swap isn't "newly added"
    assert_select ".recent-grid .book-cover-title", text: "The Hobbit", count: 0
    assert_select ".recent-grid .book-cover-title", "Dune"
  end

  test "you can only offer books you still have in a swap request" do
    sign_in_as @alice
    get new_book_exchange_request_url(books(:dune))
    assert_select "select[name=?] option", "exchange_request[offered_book_id]", text: "The Hobbit", count: 0
  end
end
