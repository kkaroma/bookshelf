class AddUserToBooks < ActiveRecord::Migration[8.1]
  # Books that already exist have no owner yet, so we can't make user_id
  # required straight away. Instead we:
  #   1. add the column as optional,
  #   2. give every existing book to the first user,
  #   3. then make the column required.
  def up
    add_reference :books, :user, foreign_key: true

    if select_value("SELECT COUNT(*) FROM books").to_i > 0
      first_user_id = select_value("SELECT id FROM users ORDER BY id LIMIT 1")
      raise "Existing books need an owner: create a user first, then migrate again." unless first_user_id

      execute "UPDATE books SET user_id = #{first_user_id.to_i}"
    end

    change_column_null :books, :user_id, false
  end

  def down
    remove_reference :books, :user, foreign_key: true
  end
end
