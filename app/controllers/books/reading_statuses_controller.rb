# Want to read / Reading / Read buttons on the owner's book page:
# PATCH /books/:book_id/reading_status
class Books::ReadingStatusesController < ApplicationController
  def update
    book = Current.user.books.find(params.expect(:book_id)) # only your own books
    status = params[:reading_status].presence
    status = nil unless status.nil? || Book.reading_statuses.key?(status)

    book.update_reading_status!(status)
    redirect_to book
  end
end
