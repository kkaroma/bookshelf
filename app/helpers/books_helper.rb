module BooksHelper
  # Picks a stable colour (0-359 on the colour wheel) from the book's title,
  # so each book gets its own "cover" colour that never changes.
  def book_cover_hue(book)
    book.title.to_s.sum % 360
  end
end
