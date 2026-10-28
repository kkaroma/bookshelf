# Genres become a list admins manage (Admin → Genres) instead of a fixed list
# in the code. Books keep storing the genre's name, so nothing else changes.
class CreateGenres < ActiveRecord::Migration[8.1]
  STARTING_GENRES = [
    "Fiction", "Fantasy", "Science fiction", "Mystery & thriller", "Romance",
    "Historical fiction", "Children's", "Young adult", "Poetry",
    "Non-fiction", "Biography & memoir", "History", "Science & nature",
    "Business & money", "Self-help", "Religion & spirituality", "Cookery",
    "Art & design", "Other"
  ].freeze

  def up
    create_table :genres do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.datetime :retired_at # hidden from new choices, kept on existing books
      t.timestamps
    end
    add_index :genres, "LOWER(name)", unique: true, name: "index_genres_on_lower_name"
    add_index :genres, :position

    # The old fixed list, in its order, then any other genre already on a book.
    in_use = select_values("SELECT DISTINCT genre FROM books WHERE genre IS NOT NULL")
    names = STARTING_GENRES + (in_use - STARTING_GENRES).sort
    names.each.with_index(1) do |name, position|
      execute "INSERT INTO genres (name, position, created_at, updated_at) VALUES (#{quote(name)}, #{position}, NOW(), NOW())"
    end
  end

  def down
    drop_table :genres
  end
end
