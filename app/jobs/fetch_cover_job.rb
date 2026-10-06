# Finds a book's cover on Open Library by its ISBN and attaches it. Runs in the
# background (Solid Queue) after a Goodreads import, so the import is instant.
class FetchCoverJob < ApplicationJob
  queue_as :default

  # Open Library is a free service that's sometimes slow: try again later.
  retry_on OpenLibrary::Error, wait: 1.minute, attempts: 3
  # The book was deleted before the job ran: nothing to do.
  discard_on ActiveJob::DeserializationError

  def perform(book)
    return if book.isbn.blank? || book.cover.attached?

    cover_id = OpenLibrary.search(isbn: book.isbn, limit: 1).first&.cover_id
    book.cover.attach(OpenLibrary.download_cover(cover_id)) if cover_id
  end
end
