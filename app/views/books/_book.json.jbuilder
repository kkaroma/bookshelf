json.extract! book, :id, :title, :subtitle, :author, :description, :published_year, :review, :user_id, :created_at, :updated_at
json.url book_url(book, format: :json)
