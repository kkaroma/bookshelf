require "test_helper"

class OpenLibraryTest < ActiveSupport::TestCase
  test "search by title returns results that have covers" do
    fake_open_library "search.json" => open_library_json([
      { "title" => "The Hobbit", "author_name" => [ "J.R.R. Tolkien" ], "cover_i" => 111,
        "first_publish_year" => 1937, "isbn" => [ "0547928226", "9780547928227" ] },
      { "title" => "The Hobbit (no cover)", "author_name" => [ "Someone" ] },
      { "title" => "The Hobbit (same cover again)", "cover_i" => 111 }
    ])

    results = OpenLibrary.search(title: "The Hobbit", author: "Tolkien")

    assert_equal 1, results.size # no-cover and duplicate covers are skipped
    hobbit = results.first
    assert_equal 111, hobbit.cover_id
    assert_equal "J.R.R. Tolkien", hobbit.author
    assert_equal 1937, hobbit.year
    assert_equal "9780547928227", hobbit.isbn # prefers the 13-digit ISBN
    assert_equal "https://covers.openlibrary.org/b/id/111-M.jpg", hobbit.thumbnail_url
  end

  test "search sends the title and author" do
    requested = nil
    fake_open_library "search.json" => ->(uri) { requested = uri.to_s; open_library_json([]) }

    OpenLibrary.search(title: "Dune", author: "Herbert")

    assert_includes requested, "title=Dune"
    assert_includes requested, "author=Herbert"
  end

  test "search uses the ISBN when there is one" do
    requested = nil
    fake_open_library "search.json" => ->(uri) { requested = CGI.unescape(uri.to_s); open_library_json([]) }

    OpenLibrary.search(title: "Dune", isbn: "978-0-441-17271-9")

    assert_includes requested, "q=isbn:9780441172719"
    assert_not_includes requested, "title="
  end

  test "search with nothing to look for makes no request" do
    assert_equal [], OpenLibrary.search(title: "", author: "Someone") # BLOCKED would raise if it called out
  end

  test "an unreadable answer raises OpenLibrary::Error" do
    fake_open_library "search.json" => OpenLibrary::Response.new(code: 200, content_type: "text/html", location: nil, body: "<html>oops")
    assert_raises(OpenLibrary::Error) { OpenLibrary.search(title: "Dune") }
  end

  test "network problems are raised as OpenLibrary::Error" do
    fake_open_library "search.json" => ->(_uri) { raise SocketError, "no internet" }
    error = assert_raises(OpenLibrary::Error) { OpenLibrary.search(title: "Dune") }
    assert_match "couldn't reach Open Library", error.message
  end

  test "an error status raises OpenLibrary::Error" do
    fake_open_library "search.json" => OpenLibrary::Response.new(code: 503, content_type: nil, location: nil, body: "")
    assert_raises(OpenLibrary::Error) { OpenLibrary.search(title: "Dune") }
  end

  test "download_cover returns the image ready for Active Storage" do
    fake_open_library "covers.openlibrary.org/b/id/42-L.jpg" => open_library_image

    attachable = OpenLibrary.download_cover(42)

    assert_equal "cover-42.jpg", attachable[:filename]
    assert_equal "image/jpeg", attachable[:content_type]
    assert_equal file_fixture("cover.jpg").binread, attachable[:io].read
  end

  test "download_cover follows a redirect to archive.org" do
    fake_open_library(
      "covers.openlibrary.org" => OpenLibrary::Response.new(code: 302, content_type: nil,
                                                            location: "https://ia800100.us.archive.org/covers/42.jpg", body: ""),
      "archive.org/covers/42.jpg" => open_library_image
    )

    assert_equal "cover-42.jpg", OpenLibrary.download_cover(42)[:filename]
  end

  test "download_cover refuses to follow a redirect anywhere else" do
    fake_open_library "covers.openlibrary.org" => OpenLibrary::Response.new(
      code: 302, content_type: nil, location: "https://evil.example.com/steal", body: "")

    error = assert_raises(OpenLibrary::Error) { OpenLibrary.download_cover(42) }
    assert_match "refusing to contact evil.example.com", error.message
  end

  test "download_cover rejects things that aren't images" do
    fake_open_library "covers.openlibrary.org" => OpenLibrary::Response.new(
      code: 200, content_type: "text/html", location: nil, body: "<html>")

    assert_raises(OpenLibrary::Error) { OpenLibrary.download_cover(42) }
  end

  test "download_cover rejects images over 5 MB" do
    fake_open_library "covers.openlibrary.org" => open_library_image("x" * (5.megabytes + 1))

    error = assert_raises(OpenLibrary::Error) { OpenLibrary.download_cover(42) }
    assert_match "too large", error.message
  end

  test "cover IDs must be numbers" do
    assert_raises(ArgumentError) { OpenLibrary.cover_url("42/../../etc") }
  end
end
