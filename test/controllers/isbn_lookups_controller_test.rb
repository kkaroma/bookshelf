require "test_helper"

class IsbnLookupsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "returns the book's details as JSON" do
    fake_open_library "search.json" => open_library_json([
      { "title" => "The Hobbit", "subtitle" => "There and Back Again", "author_name" => [ "J.R.R. Tolkien" ],
        "first_publish_year" => 1937, "cover_i" => 111 }
    ])

    get isbn_lookup_url(format: :json, isbn: "978-0-547-92822-7")

    assert_response :success
    data = response.parsed_body
    assert_equal "9780547928227", data["isbn"]
    assert_equal "The Hobbit", data["title"]
    assert_equal "J.R.R. Tolkien", data["author"]
    assert_equal 1937, data["year"]
    assert_equal 111, data["cover_id"]
    assert_equal "https://covers.openlibrary.org/b/id/111-M.jpg", data["cover_url"]
  end

  test "an invalid ISBN is rejected without asking Open Library" do
    get isbn_lookup_url(format: :json, isbn: "9780547928228") # wrong check digit; BLOCKED would raise if called
    assert_response :unprocessable_content
    assert_match "isn't a valid ISBN", response.parsed_body["error"]
  end

  test "an unknown ISBN says so" do
    fake_open_library "search.json" => open_library_json([])
    get isbn_lookup_url(format: :json, isbn: "9780547928227")
    assert_response :not_found
    assert_match "doesn't know this ISBN", response.parsed_body["error"]
  end

  test "explains when Open Library can't be reached" do
    fake_open_library "search.json" => ->(_uri) { raise SocketError }
    get isbn_lookup_url(format: :json, isbn: "9780547928227")
    assert_response :service_unavailable
  end

  test "signed-out visitors can't use it" do
    sign_out
    get isbn_lookup_url(format: :json, isbn: "9780547928227")
    assert_response :redirect
  end

  test "the book form has the ISBN lookup wired up" do
    get new_book_url
    assert_select "form[data-controller~=isbn-lookup][data-isbn-lookup-url-value=?]", isbn_lookup_path(format: :json)
    assert_select "input[name=?][data-isbn-lookup-target=isbn]", "book[isbn]"
    assert_select "button", "Look up"
  end
end
