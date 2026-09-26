class AddSubtitleAndReviewToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :subtitle, :string
    add_column :books, :review, :text
  end
end
