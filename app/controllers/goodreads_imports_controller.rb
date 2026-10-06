# Import from Goodreads: upload the CSV from Goodreads' "Export Library".
class GoodreadsImportsController < ApplicationController
  MAX_FILE_SIZE = 5.megabytes

  def new
    @shelves = GoodreadsImport::DEFAULT_SHELVES
  end

  def create
    file = params[:file]
    @shelves = Array(params[:shelves]) & GoodreadsImport::SHELVES.keys

    @error =
      if file.blank? then "Choose your Goodreads export file first."
      elsif file.size > MAX_FILE_SIZE then "That file is too large (the limit is 5 MB)."
      elsif @shelves.empty? then "Tick at least one Goodreads shelf to import."
      end
    return render(:new, status: :unprocessable_content) if @error

    result = GoodreadsImport.new(user: Current.user, csv: file.read, shelves: @shelves).run
    redirect_to user_path(Current.user), notice: summary(result)
  rescue GoodreadsImport::InvalidFile => error
    @error = error.message
    render :new, status: :unprocessable_content
  end

  private
    def summary(result)
      parts = [ "Imported #{helpers.pluralize(result.imported.size, "book")} from Goodreads." ]
      parts << "#{helpers.pluralize(result.duplicates, "book")} already on your shelf." if result.duplicates.positive?
      parts << "#{result.other_shelves} on other Goodreads shelves left out." if result.other_shelves.positive?
      parts << "#{result.invalid} couldn't be imported (missing title or author)." if result.invalid.positive?
      parts << "Covers are being added in the background." if result.imported.any?(&:isbn)
      parts.join(" ")
    end
end
