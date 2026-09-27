class CreateExchangeRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_requests do |t|
      # Who is asking, and for which book (the book's owner answers).
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :book, null: false, foreign_key: true
      # Optionally, one of the requester's own books offered in return.
      t.references :offered_book, foreign_key: { to_table: :books }
      t.text :message
      # 0 = pending, 1 = accepted, 2 = declined, 3 = cancelled (see the enum in the model)
      t.integer :status, null: false, default: 0
      t.datetime :responded_at

      t.timestamps
    end

    # At most one *pending* request per person per book. This is a "partial"
    # index: it only covers rows where status = 0, so you can ask again after
    # a request was declined or cancelled.
    add_index :exchange_requests, [ :requester_id, :book_id ], unique: true,
              where: "status = 0", name: "index_exchange_requests_one_pending_per_book"
  end
end
