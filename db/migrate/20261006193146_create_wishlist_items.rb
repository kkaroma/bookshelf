class CreateWishlistItems < ActiveRecord::Migration[8.1]
  def change
    # "Tell me when someone offers this book for exchange."
    create_table :wishlist_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :author
      t.string :isbn

      t.timestamps
    end
    add_index :wishlist_items, :isbn
  end
end
