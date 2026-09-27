class AddCounterCachesToUsers < ActiveRecord::Migration[8.1]
  # Counter caches: Rails keeps these numbers up to date automatically
  # (see `counter_cache:` in Book and Follow), so lists of members can show
  # "3 books · 5 followers" without counting rows for every person.
  def up
    add_column :users, :books_count, :integer, null: false, default: 0
    add_column :users, :followers_count, :integer, null: false, default: 0
    add_column :users, :following_count, :integer, null: false, default: 0

    # Existing users already have books, so fill in their starting count.
    execute <<~SQL
      UPDATE users SET books_count = (SELECT COUNT(*) FROM books WHERE books.user_id = users.id)
    SQL
  end

  def down
    remove_column :users, :books_count
    remove_column :users, :followers_count
    remove_column :users, :following_count
  end
end
