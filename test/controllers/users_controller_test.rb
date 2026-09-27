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
end
