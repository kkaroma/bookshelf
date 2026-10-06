# Answers the book form's "Look up" button with JSON (data, not a web page),
# which the isbn-lookup Stimulus controller uses to fill in the form.
#   GET /isbn_lookup.json?isbn=9780547928227
class IsbnLookupsController < ApplicationController
  # Be a good neighbour to Open Library's free service.
  rate_limit to: 30, within: 1.minute, with: -> { render json: { error: "Too many lookups - wait a minute and try again." }, status: :too_many_requests }

  def show
    isbn = params[:isbn].to_s.upcase.gsub(/[^0-9X]/, "")

    unless Book.valid_isbn?(isbn)
      return render json: { error: "That isn't a valid ISBN - check the digits." }, status: :unprocessable_content
    end

    details = OpenLibrary.lookup_isbn(isbn)
    if details
      render json: details.to_h.merge(cover_url: details.cover_url)
    else
      render json: { error: "Open Library doesn't know this ISBN. You can still type the details in." }, status: :not_found
    end
  rescue OpenLibrary::Error
    render json: { error: "Couldn't reach Open Library just now. Try again in a moment." }, status: :service_unavailable
  end
end
