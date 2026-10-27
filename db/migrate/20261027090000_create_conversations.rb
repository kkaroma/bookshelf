# Private messages between two members: one conversation per pair, its
# messages, and blocks (who doesn't want messages from whom).
class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      # The pair is stored with the smaller user id first, so Alice→Bob and
      # Bob→Alice are the same row (see Conversation.between).
      t.references :user_one, null: false, foreign_key: { to_table: :users }
      t.references :user_two, null: false, foreign_key: { to_table: :users }
      t.references :started_by, null: false, foreign_key: { to_table: :users }
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :conversations, %i[user_one_id user_two_id], unique: true
    add_index :conversations, :last_message_at
    add_check_constraint :conversations, "user_one_id < user_two_id", name: "conversations_users_in_order"

    create_table :direct_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.datetime :read_at
      t.timestamps
    end
    add_index :direct_messages, %i[conversation_id created_at]
    add_index :direct_messages, %i[conversation_id read_at]

    create_table :blocks do |t|
      t.references :blocker, null: false, foreign_key: { to_table: :users }
      t.references :blocked, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :blocks, %i[blocker_id blocked_id], unique: true
  end
end
