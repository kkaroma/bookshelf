json.extract! book, :id, :title, :subtitle, :author, :isbn, :description, :published_year, :review, :available_for_exchange, :user_id, :created_at, :updated_at
json.url book_url(book, format: :json)
