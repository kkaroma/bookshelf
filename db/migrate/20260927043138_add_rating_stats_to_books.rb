class AddRatingStatsToBooks < ActiveRecord::Migration[8.1]
  # Stored on the book so pages can show "★ 4.3 (12)" without
  # counting and averaging every rating each time.
  def change
    add_column :books, :ratings_count, :integer, null: false, default: 0
    add_column :books, :average_rating, :decimal, precision: 2, scale: 1
  end
end
