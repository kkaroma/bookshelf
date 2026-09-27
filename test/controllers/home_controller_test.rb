require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  # --- Visitors ---

  test "visitors see a welcome page that explains the site" do
    get root_url

    assert_response :success
    assert_select "h1", /Keep track of the books you own/
    assert_select "a[href=?]", new_registration_path, text: "Create your free account"
    assert_select "a[href=?]", new_session_path, text: "Sign in"
    assert_select ".feature", 4
    assert_select ".steps li", 3
  end

  test "visitors see recent covers and titles, but not reviews or who owns them" do
    get root_url

    assert_select ".recent .book-card-title", "The Hobbit"
    assert_select ".recent .book-card-title", "Dune"
    assert_select ".recent", /2 books shared by 3 readers/
    assert_no_match "Added by", response.body
    assert_no_match "cosy adventure", response.body   # The Hobbit's review
    assert_no_match "Bob Bookworm", response.body
    assert_select ".recent a[href=?]", book_path(books(:hobbit)), count: 0 # book pages need an account
  end

  test "the welcome page works before anyone has added books" do
    Book.destroy_all
    get root_url

    assert_response :success
    assert_select ".recent", count: 0
    assert_select ".hero-covers", count: 0
  end

  # --- Members ---

  test "members see their Home page instead" do
    sign_in_as users(:one)
    get root_url

    assert_select "h1", "Welcome back, Alice"
    assert_select "h1", text: /Keep track/, count: 0
  end

  test "new members see the getting-started checklist" do
    newbie = User.create!(name: "Nora New", email_address: "nora@example.com", password: "password123")
    sign_in_as newbie
    get root_url

    assert_select ".checklist h2", "Getting started"
    assert_select ".checklist", /0 of 5 done/
    assert_select ".checklist-step a", "Add your first book"
    assert_select ".checklist-step a[href=?]", users_path, text: "Follow a member"
  end

  test "finished steps are ticked and the checklist disappears when all are done" do
    alice = users(:one) # has a book with a review; not following anyone
    sign_in_as alice
    get root_url
    assert_select ".checklist-step.done", 2 # added a book, wrote a review

    books(:hobbit).cover.attach(io: file_fixture("cover.jpg").open, filename: "c.jpg", content_type: "image/jpeg")
    books(:hobbit).update!(available_for_exchange: true)
    alice.follow(users(:two))

    get root_url
    assert_select ".checklist", count: 0
  end

  test "points out exchange requests waiting for an answer" do
    sign_in_as users(:two) # Bob has one pending request for Dune
    get root_url
    assert_select ".attention a[href=?]", exchange_requests_path, text: /1 exchange request\s+waiting/
  end

  test "shows books from people you follow" do
    sign_in_as users(:two) # Bob follows Alice
    get root_url
    assert_select "#following #book_#{books(:hobbit).id}"
  end

  test "suggests finding members when you follow no one" do
    sign_in_as users(:one)
    get root_url
    assert_select "#following .home-empty a[href=?]", users_path
  end

  test "the exchange section shows other people's books, not your own" do
    sign_in_as users(:one)
    get root_url
    assert_select "#exchange #book_#{books(:dune).id}"

    sign_out
    sign_in_as users(:two) # Dune is Bob's own
    get root_url
    assert_select "#exchange #book_#{books(:dune).id}", count: 0
  end

  test "your books section links to all your books" do
    sign_in_as users(:one)
    get root_url
    assert_select "#my_books #book_#{books(:hobbit).id}"
    assert_select "#my_books a[href=?]", user_path(users(:one)), text: "See all →"
  end
end
