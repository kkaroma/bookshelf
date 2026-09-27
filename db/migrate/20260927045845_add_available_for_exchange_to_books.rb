class AddAvailableForExchangeToBooks < ActiveRecord::Migration[8.1]
  def change
    # Off by default: a book is only offered for exchange when its owner says so.
    add_column :books, :available_for_exchange, :boolean, null: false, default: false
    # The exchange shelf looks books up by this column, so index it.
    add_index :books, :available_for_exchange
  end
end
