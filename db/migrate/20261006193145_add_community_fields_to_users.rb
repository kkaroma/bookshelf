class AddCommunityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Optional town or city, so swaps can be arranged with people nearby.
    add_column :users, :city, :string
    # Email switches for the new kinds of notification (on by default).
    add_column :users, :notify_messages, :boolean, null: false, default: true
    add_column :users, :notify_wishlist, :boolean, null: false, default: true
  end
end
