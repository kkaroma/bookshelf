require "test_helper"

# What visitors (no account) can and can't see.
class PublicPagesTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)   # owns The Hobbit (reviewed, commented on by Bob)
    @bob = users(:two)     # owns Dune
    @hobbit = books(:hobbit)
    @alice.update!(public_profile: true, city: "Arusha")
  end

  # --- Private by default ---

  test "a private member's profile and books still need signing in" do
    get user_url(@bob)
    assert_redirected_to new_session_url
    get book_url(books(:dune))
    assert_redirected_to new_session_url
  end

  test "suspended members' pages are never public" do
    @alice.suspend!
    get user_url(@alice)
    assert_redirected_to new_session_url
  end

  test "lists and everything else still need signing in" do
    [ books_url, users_url, exchanges_url, followers_user_url(@alice), year_in_books_url ].each do |url|
      get url
      assert_redirected_to new_session_url, url
    end
  end

  # --- A public book page ---

  test "a public member's book page shows the book and review" do
    get book_url(@hobbit)

    assert_response :success
    assert_select "h1", "The Hobbit"
    assert_select ".book-review-text", /cosy adventure/
    assert_select ".pill a[href=?]", user_path(@alice), "Alice Reader"
    assert_select ".public-rating", /4.5 from 2 ratings/
    assert_select ".join-card", /2 comments/ # Bob's comment and Alice's reply
    assert_select ".share[data-share-url-value=?]", book_url(@hobbit)
  end

  test "the book page never shows comments, lending, swaps or controls" do
    @hobbit.loans.create!(borrower_name: "Secret Borrower", lent_on: Date.current)
    get book_url(@hobbit)

    assert_no_match comments(:bob_on_hobbit).body, response.body
    assert_no_match comments(:alice_reply_to_bob).body, response.body
    assert_no_match "Secret Borrower", response.body
    assert_no_match @alice.email_address, response.body
    assert_no_match "Arusha", response.body
    assert_select "form[action*=?]", "/rating", 0
    assert_select "a", text: "Edit book", count: 0
    assert_select "button", text: "Request exchange", count: 0
  end

  test "link previews: title, description, cover and canonical address" do
    @hobbit.cover.attach(fixture_file_upload("cover.jpg", "image/jpeg"))
    get book_url(@hobbit)

    assert_select "meta[property='og:title'][content=?]", "The Hobbit by J.R.R. Tolkien — Alice Reader on Bookshelf"
    assert_select "meta[property='og:description'][content^=?]", "A cosy adventure"
    assert_select "meta[property='og:image'][content^=?]", "http://www.example.com/rails/active_storage/representations"
    assert_select "link[rel=canonical][href=?]", book_url(@hobbit)
  end

  test "readable addresses, and old ones still work" do
    assert_equal "#{@hobbit.id}-the-hobbit", @hobbit.to_param
    get "/books/#{@hobbit.id}" # a link made before names were added
    assert_response :success
    assert_equal "#{@alice.id}-alice-reader", @alice.to_param
  end

  # --- A public profile ---

  test "a public profile shows books, books they've had and reviews - nothing private" do
    @hobbit.hand_over_to!(@bob) # now a book Alice has had
    Book.create!(user: @alice, title: "Emma", author: "Jane Austen")
    WishlistItem.create!(user: @alice, title: "Secret wish")
    get user_url(@alice)

    assert_response :success
    assert_select "h1", "Alice Reader"
    assert_select ".book-grid .book-card", 2 # Emma, and the Hobbit under books she's had
    assert_select ".past-books .book-card-title", "The Hobbit"
    assert_select ".public-reviews li", /The Hobbit/
    assert_no_match "Arusha", response.body
    assert_no_match @alice.email_address, response.body
    assert_no_match "Secret wish", response.body
    assert_no_match "Bob Bookworm", response.body # not who she swapped with, or who follows her
    assert_select ".profile-stats", /1\s+follower/
  end

  test "asking for JSON gets nothing" do
    get book_url(@hobbit, format: :json)
    assert_redirected_to new_session_url
  end

  # --- Sitemap and welcome page ---

  test "the sitemap lists only public members and their books" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match user_url(@alice), response.body
    assert_match book_url(@hobbit), response.body
    assert_no_match user_url(@bob), response.body
    assert_no_match book_url(books(:dune)), response.body
  end

  test "the welcome page links public books only" do
    get root_url
    assert_select ".recent-grid a.book-card[href=?]", book_path(@hobbit)
    assert_select ".recent-grid a.book-card[href=?]", book_path(books(:dune)), 0
  end
end
