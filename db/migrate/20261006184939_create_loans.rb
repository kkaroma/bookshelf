class CreateLoans < ActiveRecord::Migration[8.1]
  def change
    # Lending a book: who has it, since when, when it's due back, and when it came back.
    create_table :loans do |t|
      t.references :book, null: false, foreign_key: true
      t.string :borrower_name, null: false
      t.date :lent_on, null: false
      t.date :due_on
      t.date :returned_on
      t.text :note

      t.timestamps
    end
    # A book can only be out with one person at a time: at most one loan per
    # book that hasn't been returned (a "partial" unique index).
    add_index :loans, :book_id, unique: true, where: "returned_on IS NULL", name: "index_loans_one_open_per_book"
  end
end
