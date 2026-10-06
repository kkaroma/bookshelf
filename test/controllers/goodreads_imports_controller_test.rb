require "test_helper"

class GoodreadsImportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  def upload(name = "goodreads_library_export.csv", type = "text/csv")
    fixture_file_upload(name, type)
  end

  test "the Books page links to the import" do
    get books_url
    assert_select "a[href=?]", new_goodreads_import_path, text: "Import from Goodreads"
  end

  test "the import page explains how to export and picks sensible shelves" do
    get new_goodreads_import_url
    assert_select "h1", "Import from Goodreads"
    assert_select ".import-steps li", 4
    assert_select "input[type=checkbox][value=read][checked]"
    assert_select "input[type=checkbox][value=currently-reading][checked]"
    assert_select "input[type=checkbox][value=to-read]:not([checked])"
  end

  test "importing adds the books and says what happened" do
    assert_difference("users(:one).books.count", 2) do
      post goodreads_import_url, params: { file: upload, shelves: %w[ read currently-reading ] }
    end

    assert_redirected_to user_path(users(:one))
    follow_redirect!
    assert_select ".flash-notice", /Imported 2 books from Goodreads/
    assert_select ".flash-notice", /1 book already on your shelf/
    assert_select ".flash-notice", /Covers are being added/
  end

  test "you must choose a file and at least one shelf" do
    post goodreads_import_url, params: { shelves: %w[ read ] }
    assert_response :unprocessable_content
    assert_select ".form-errors", /Choose your Goodreads export file/

    post goodreads_import_url, params: { file: upload }
    assert_select ".form-errors", /Tick at least one Goodreads shelf/
  end

  test "a file that isn't a Goodreads export is refused" do
    assert_no_difference("Book.count") do
      post goodreads_import_url, params: { file: upload("not_an_image.txt", "text/plain"), shelves: %w[ read ] }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /doesn't look like a Goodreads export/
  end

  test "signed-out visitors are sent to sign in" do
    sign_out
    get new_goodreads_import_url
    assert_redirected_to new_session_url
  end
end
