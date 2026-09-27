class AddIsbnToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :isbn, :string
  end
end
