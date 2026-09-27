class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :score, null: false

      t.timestamps
    end
    # One rating per person per book, guaranteed by the database itself.
    add_index :ratings, [ :user_id, :book_id ], unique: true
  end
end
