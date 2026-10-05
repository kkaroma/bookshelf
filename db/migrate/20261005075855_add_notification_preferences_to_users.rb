class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.1]
  # Which emails each member wants. Everyone starts with all of them on and
  # can switch them off under Settings → Notifications.
  def change
    add_column :users, :notify_exchange_requests, :boolean, null: false, default: true
    add_column :users, :notify_comments,          :boolean, null: false, default: true
    add_column :users, :notify_followers,         :boolean, null: false, default: true
  end
end
