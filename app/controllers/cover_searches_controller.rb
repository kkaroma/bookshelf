# Searches Open Library for covers and shows them inside the book form
# (the result is loaded into a Turbo Frame).
class CoverSearchesController < ApplicationController
  # Be a good neighbour to Open Library's free service.
  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  def show
    @query = params.permit(:title, :author, :isbn).to_h.symbolize_keys.compact_blank
    @results = OpenLibrary.search(**@query)
  rescue OpenLibrary::Error
    @results = []
    @failed = true
  end
end
