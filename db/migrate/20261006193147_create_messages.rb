class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    # Messages between the two people in an exchange request.
    create_table :messages do |t|
      t.references :exchange_request, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end
  end
end
