# Books leave a shelf without disappearing: a swap gives the new owner a new
# copy, and the old copy - with its review, comments and ratings - stays on
# the giver's profile under "Books I've had".
class AddGivenAwayToBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :books, :given_away_at, :datetime
    add_reference :books, :given_to, foreign_key: { to_table: :users, on_delete: :nullify }
    add_reference :books, :successor, foreign_key: { to_table: :books, on_delete: :nullify }
    add_index :books, %i[user_id given_away_at]

    backfill_completed_swaps
  end

  def down
    # Undo the backfill: point requests back at the copies people now own,
    # then drop the given-away copies the backfill made.
    execute <<~SQL
      UPDATE exchange_requests r SET book_id = b.successor_id
      FROM books b WHERE r.book_id = b.id AND b.successor_id IS NOT NULL
    SQL
    execute <<~SQL
      UPDATE exchange_requests r SET offered_book_id = b.successor_id
      FROM books b WHERE r.offered_book_id = b.id AND b.successor_id IS NOT NULL
    SQL
    execute "DELETE FROM books WHERE given_away_at IS NOT NULL"
    remove_index :books, %i[user_id given_away_at]
    remove_reference :books, :successor, foreign_key: { to_table: :books }
    remove_reference :books, :given_to, foreign_key: { to_table: :users }
    remove_column :books, :given_away_at
  end

  private
    # Swaps completed before this change *moved* each book to its new owner,
    # so the giver has no record of it. Give each giver back a "Books I've
    # had" entry (title, author and so on - the review was already gone) and
    # point the request at it, the way new swaps work.
    def backfill_completed_swaps
      swaps = select_all(<<~SQL).to_a
        SELECT id, requester_id, owner_id, book_id, offered_book_id, completed_at
        FROM exchange_requests WHERE status = 4 AND completed_at IS NOT NULL
      SQL

      swaps.each do |swap|
        # The requested book went requester-wards; the offered one went owner-wards.
        book = past_copy(swap["book_id"], giver: swap["owner_id"], receiver: swap["requester_id"], on: swap["completed_at"])
        execute "UPDATE exchange_requests SET book_id = #{book} WHERE id = #{swap["id"].to_i}" if book

        if swap["offered_book_id"]
          offered = past_copy(swap["offered_book_id"], giver: swap["requester_id"], receiver: swap["owner_id"], on: swap["completed_at"])
          execute "UPDATE exchange_requests SET offered_book_id = #{offered} WHERE id = #{swap["id"].to_i}" if offered
        end
      end

      # books_count now means books still on the shelf.
      execute <<~SQL
        UPDATE users SET books_count = (SELECT COUNT(*) FROM books WHERE books.user_id = users.id AND books.given_away_at IS NULL)
      SQL
    end

    # Inserts the giver's given-away copy of `book_id`; returns its id.
    def past_copy(book_id, giver:, receiver:, on:)
      return if book_id.nil?

      select_value(<<~SQL)
        INSERT INTO books (user_id, title, subtitle, author, description, published_year, isbn, genre,
                           available_for_exchange, ratings_count, given_away_at, given_to_id, successor_id,
                           created_at, updated_at)
        SELECT #{giver.to_i}, title, subtitle, author, description, published_year, isbn, genre,
               false, 0, #{quote(on)}, #{receiver.to_i}, id, created_at, NOW()
        FROM books WHERE id = #{book_id.to_i}
        RETURNING id
      SQL
    end
end
