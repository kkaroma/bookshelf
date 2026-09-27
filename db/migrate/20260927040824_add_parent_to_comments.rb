class AddParentToComments < ActiveRecord::Migration[8.1]
  def change
    # A reply points at the comment it answers. Top-level comments leave it empty.
    add_reference :comments, :parent, foreign_key: { to_table: :comments }
  end
end
