# A member reporting a book or comment to the admins.
class CreateFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :flags do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :flaggable, null: false, polymorphic: true
      t.string :reason, null: false
      t.text :note
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    # At most one open report per member per book/comment.
    add_index :flags, %i[reporter_id flaggable_type flaggable_id], unique: true,
              where: "resolved_at IS NULL", name: "index_flags_one_open_per_reporter"
    add_index :flags, :resolved_at
  end
end
