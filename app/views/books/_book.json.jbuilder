json.extract! book, :id, :title, :subtitle, :author, :description, :published_year, :review, :created_at, :updated_at
json.url book_url(book, format: :json)
