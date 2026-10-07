class AddModerationFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_confirmed_at, :datetime
    add_column :users, :suspended_at, :datetime
    add_index :users, :suspended_at

    # Everyone who joined before email confirmation existed counts as confirmed.
    execute "UPDATE users SET email_confirmed_at = created_at"
  end

  def down
    remove_index :users, :suspended_at
    remove_column :users, :suspended_at
    remove_column :users, :email_confirmed_at
  end
end
