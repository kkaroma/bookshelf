class AddOwnerToExchangeRequests < ActiveRecord::Migration[8.1]
  # Who owned the requested book when the request was made. Until now this was
  # worked out from the book, but completing a swap moves the book to its new
  # owner - so the request needs to remember the original owner itself.
  def up
    add_reference :exchange_requests, :owner, foreign_key: { to_table: :users }
    execute <<~SQL
      UPDATE exchange_requests
      SET owner_id = books.user_id
      FROM books
      WHERE books.id = exchange_requests.book_id
    SQL
    change_column_null :exchange_requests, :owner_id, false
  end

  def down
    remove_reference :exchange_requests, :owner, foreign_key: { to_table: :users }
  end
end
