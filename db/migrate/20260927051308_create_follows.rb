class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    # "follower follows followed" - both columns point at the users table.
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    # You can only follow someone once.
    add_index :follows, [ :follower_id, :followed_id ], unique: true
  end
end
