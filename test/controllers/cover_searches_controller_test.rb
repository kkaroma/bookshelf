require "test_helper"

class CoverSearchesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "shows matching covers as buttons to pick" do
    fake_open_library "search.json" => open_library_json([
      { "title" => "The Hobbit", "author_name" => [ "J.R.R. Tolkien" ], "cover_i" => 111,
        "first_publish_year" => 1937, "isbn" => [ "9780547928227" ] },
      { "title" => "The Hobbit: Illustrated", "cover_i" => 222 }
    ])

    get cover_search_url(title: "The Hobbit", author: "Tolkien")

    assert_response :success
    assert_select "turbo-frame#cover_results button.cover-result", 2
    assert_select "button[data-cover-picker-id-param='111'][data-cover-picker-isbn-param='9780547928227']"
    assert_select "button[aria-label=?]", "Use cover: The Hobbit, 1937"
    assert_select "img[src=?]", "https://covers.openlibrary.org/b/id/111-M.jpg"
  end

  test "says so when nothing is found" do
    fake_open_library "search.json" => open_library_json([])
    get cover_search_url(title: "Zzzz")
    assert_select ".cover-results-message", /No covers found for “Zzzz”/
  end

  test "asks for a title when the form is empty" do
    get cover_search_url(title: "", author: "")
    assert_select ".cover-results-message", /Type a title or ISBN first/
  end

  test "explains when Open Library can't be reached" do
    fake_open_library "search.json" => ->(_uri) { raise SocketError }
    get cover_search_url(title: "Dune")

    assert_response :success
    assert_select ".cover-results-message", /Couldn't reach Open Library/
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get cover_search_url(title: "Dune")
    assert_redirected_to new_session_url
  end
end
