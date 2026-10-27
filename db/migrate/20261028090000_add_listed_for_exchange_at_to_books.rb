# When a book was last put on the Exchange shelf - for the Swaps report's
# "on the shelf longest with no requests".
class AddListedForExchangeAtToBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :books, :listed_for_exchange_at, :datetime
    # Best guess for books already on the shelf: when they were last changed.
    execute "UPDATE books SET listed_for_exchange_at = updated_at WHERE available_for_exchange"
  end

  def down
    remove_column :books, :listed_for_exchange_at
  end
end
