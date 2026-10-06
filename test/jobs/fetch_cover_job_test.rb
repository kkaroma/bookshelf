require "test_helper"

class FetchCoverJobTest < ActiveJob::TestCase
  setup { @book = books(:hobbit).tap { |book| book.update!(isbn: "9780547928227") } }

  test "finds the cover by ISBN and attaches it" do
    fake_open_library(
      "search.json" => open_library_json([ { "title" => "The Hobbit", "cover_i" => 111 } ]),
      "covers.openlibrary.org/b/id/111-L.jpg" => open_library_image
    )

    FetchCoverJob.perform_now(@book)
    assert @book.reload.cover_ready?
  end

  test "does nothing if the book already has a cover or has no ISBN" do
    @book.cover.attach(io: file_fixture("cover.png").open, filename: "mine.png", content_type: "image/png")
    FetchCoverJob.perform_now(@book) # BLOCKED fetcher would raise if Open Library were called
    assert_equal "mine.png", @book.reload.cover.filename.to_s

    books(:dune).update!(isbn: nil)
    FetchCoverJob.perform_now(books(:dune))
    assert_not books(:dune).reload.cover.attached?
  end

  test "Open Library having no cover is fine" do
    fake_open_library "search.json" => open_library_json([])
    FetchCoverJob.perform_now(@book)
    assert_not @book.reload.cover.attached?
  end

  test "is retried later if Open Library can't be reached" do
    fake_open_library "search.json" => ->(_uri) { raise SocketError }
    assert_enqueued_with(job: FetchCoverJob) do
      FetchCoverJob.perform_now(@book)
    end
  end
end
