require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    @bob   = users(:two) # follows Alice
    sign_in_as @alice
  end

  test "members page lists everyone with follow buttons" do
    get users_url

    assert_response :success
    assert_select "h1", "Members"
    assert_select ".member", User.count
    assert_select "#user_#{@bob.id} button", "Follow"
    assert_select "#user_#{@alice.id} .pill", "You" # no button for yourself
    assert_select "#user_#{@alice.id} button", count: 0
  end

  test "profile shows the person's books and counts" do
    get user_url(@bob)

    assert_select "h1", /Bob Bookworm/
    assert_select ".profile-stats", /1\s+book/
    assert_select ".profile-stats", /1\s+following/
    assert_select ".section-title", "Bob Bookworm's books"
    assert_select "#books .book-card", 1
    assert_select "#book_#{books(:dune).id}"
  end

  test "your own profile says My books" do
    get user_url(@alice)
    assert_select ".section-title", "My books"
    assert_select ".follow-box .pill", "You"
  end

  # --- Searching a profile's books ---

  test "your profile has a search box for your own books" do
    get user_url(@alice)
    assert_select "form[role=search][action=?]", user_path(@alice)
    assert_select "label", "Search my books"
    assert_select "#books_results .book-card", 1
  end

  test "someone else's profile searches their books" do
    get user_url(@bob)
    assert_select "label", "Search Bob Bookworm's books"
  end

  test "profile search only looks at that person's books" do
    get user_url(@alice, q: "hobbit")
    assert_select "#book_#{books(:hobbit).id}"
    assert_select ".search-summary", /1 book\s+matching “hobbit”/
    assert_select ".search-summary a[href=?]", user_path(@alice), text: "Clear search"

    get user_url(@alice, q: "dune") # Dune exists, but it's Bob's
    assert_select ".book-card", count: 0
    assert_select ".empty-state h2", "No books match “dune”"
    assert_select ".empty-state a[href=?]", user_path(@alice), text: "Show all books"
  end

  test "profiles can filter by reading status and show what's being read" do
    books(:hobbit).update_reading_status!("reading")

    get user_url(@alice)
    assert_select "select[name=status]"
    assert_select ".currently-reading", /I'm currently reading:\s+The Hobbit/

    get user_url(@alice, status: "read")
    assert_select ".book-card", 0
    assert_select ".empty-state h2", "No books match these filters"
  end

  test "a profile with no books says so, without a search summary" do
    newbie = User.create!(name: "Nora New", email_address: "nora@example.com", password: "password123")
    get user_url(newbie)
    assert_select "p.muted", "Nora New hasn't added any books yet."
    assert_select ".search-summary", count: 0
  end

  test "the members list is split into pages of 30" do
    31.times { |i| User.create!(name: format("Reader %02d", i), email_address: "r#{i}@example.com", password: "password123") }

    get users_url
    assert_select ".member", 30
    assert_select ".search-summary", /34 readers/
    assert_select ".pagination a[rel=next][href=?]", users_path(page: 2)
  end

  test "followers page lists the people who follow someone" do
    get followers_user_url(@alice)

    assert_select "h1", "Followers"
    assert_select ".member", 1
    assert_select "#user_#{@bob.id}"
  end

  test "following page lists the people someone follows" do
    get following_user_url(@bob)

    assert_select "h1", "Following"
    assert_select "#user_#{@alice.id}"
  end

  test "empty lists show a friendly message" do
    get following_user_url(@alice)
    assert_select "p.muted", "Alice Reader isn't following anyone yet."
  end

  test "names link to profiles" do
    get book_url(books(:dune))
    assert_select ".pill a[href=?]", user_path(@bob), "Bob Bookworm"

    get books_url
    assert_select ".nav-user a[href=?]", user_path(@alice), "Alice Reader"
  end

  test "comment authors link to their profile" do
    get book_url(books(:hobbit))
    assert_select "a.comment-author[href=?]", user_path(@bob), "Bob Bookworm"
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get users_url
    assert_redirected_to new_session_url
  end

  test "suspended members are left out of the Members list" do
    @bob.suspend!
    get users_url
    assert_select "#user_#{@bob.id}", count: 0
    assert_select ".member", User.count - 1
  end

  test "only admins see that a profile is suspended" do
    @bob.suspend!
    get user_url(@bob)
    assert_select ".badge", text: "Suspended", count: 0

    sign_out
    sign_in_as users(:admin)
    get user_url(@bob)
    assert_select ".badge", "Suspended"
  end

  test "the members page has a search box" do
    get users_url
    assert_select "form[role=search] input[type=search][name=q][placeholder=?]", "Search by name or town"
    assert_select "turbo-frame#members_results[target=_top]"
  end

  test "searching shows only matching members" do
    @bob.update!(city: "Dar es Salaam")
    get users_url(q: "dar")

    assert_select ".member", 1
    assert_select "#user_#{@bob.id}"
    assert_select ".search-summary", /1 member\s+matching “dar”/
    assert_select ".search-summary a[href=?]", users_path, "Clear search"
    assert_select "input[name=q][value=?]", "dar"
  end

  test "a search with no results says so" do
    get users_url(q: "zzzz")
    assert_select ".member", 0
    assert_select ".empty-state h2", "No members match “zzzz”"
  end

  test "suspended members can't be found" do
    @bob.suspend!
    get users_url(q: "bookworm")
    assert_select ".member", 0
  end

  test "page links keep the search" do
    35.times { |i| User.create!(name: format("Zed Reader %02d", i), email_address: "zed#{i}@example.com", password: "password123") }
    get users_url(q: "zed")
    assert_select ".search-summary", /35 members/
    assert_select ".pagination a[rel=next][href=?]", users_path(q: "zed", page: 2)
  end
end
