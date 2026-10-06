class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    # In-app notifications (the bell): "Bob commented on The Hobbit".
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :actor, foreign_key: { to_table: :users }        # who did it (optional)
      t.references :notifiable, polymorphic: true, null: false      # what it's about: a Comment, Follow, ...
      t.string :kind, null: false                                   # e.g. "comment", "new_follower"
      t.datetime :read_at

      t.timestamps
    end
    add_index :notifications, [ :recipient_id, :read_at ]
    add_index :notifications, [ :recipient_id, :created_at ]
  end
end
