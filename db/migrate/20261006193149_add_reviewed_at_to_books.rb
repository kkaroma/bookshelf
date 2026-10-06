class AddReviewedAtToBooks < ActiveRecord::Migration[8.1]
  def change
    # When the owner last wrote or changed their review (for the activity feed).
    add_column :books, :reviewed_at, :datetime
  end
end
