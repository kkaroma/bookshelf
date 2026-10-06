class AddReadingDetailsToBooks < ActiveRecord::Migration[8.1]
  def change
    # One genre per book, from a fixed list (Book::GENRES).
    add_column :books, :genre, :string
    add_index :books, :genre

    # The owner's reading of their copy: nil (not set), 0 want to read,
    # 1 reading, 2 read - see the enum in Book.
    add_column :books, :reading_status, :integer
    add_column :books, :started_on, :date
    add_column :books, :finished_on, :date
    add_index :books, [ :user_id, :finished_on ] # reading-goal counts: books I finished this year
  end
end
