class CreateReadingGoals < ActiveRecord::Migration[8.1]
  def change
    # "Read 20 books in 2026" - one goal per member per year.
    create_table :reading_goals do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :target, null: false

      t.timestamps
    end
    add_index :reading_goals, [ :user_id, :year ], unique: true
  end
end
