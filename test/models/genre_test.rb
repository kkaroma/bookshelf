require "test_helper"

class GenreTest < ActiveSupport::TestCase
  test "names are tidied, required, and unique ignoring capitals" do
    assert_equal "Swahili literature", Genre.create!(name: "  Swahili   literature ").name
    assert_not Genre.new(name: "").valid?
    duplicate = Genre.new(name: "fantasy")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists"
  end

  test "new genres go to the end of the list" do
    Genre.create!(name: "Swahili literature")
    assert_equal "Swahili literature", Genre.names.last
  end

  test "renaming a genre renames it on every book" do
    books(:hobbit).update!(genre: "Fantasy")
    genres(:fantasy).update!(name: "Fantasy & myth")

    assert_equal "Fantasy & myth", books(:hobbit).reload.genre
    assert_not Book.exists?(genre: "Fantasy")
  end

  test "a genre in use can't be deleted - retire it instead" do
    books(:hobbit).update!(genre: "Fantasy")
    assert_not genres(:fantasy).destroy
    assert_match(/used by 1 book\. Retire it instead/, genres(:fantasy).errors.full_messages.to_sentence)

    assert genres(:cookery).destroy # nobody uses Cookery
  end

  test "retired genres aren't offered for new choices, but books keep them" do
    books(:hobbit).update!(genre: "Fantasy")
    genres(:fantasy).retire!

    assert_not_includes Genre.choices_for(books(:dune)), "Fantasy"
    assert_includes Genre.choices_for(books(:hobbit)), "Fantasy" # its own genre stays in its form
    assert books(:hobbit).reload.update(title: "The Hobbit (again)") # still valid
    assert Book.new(user: users(:one), title: "T", author: "A", genre: "Fantasy").valid? # still a real genre

    genres(:fantasy).restore!
    assert_includes Genre.choices_for(books(:dune)), "Fantasy"
  end

  test "moving up and down swaps places" do
    assert_equal %w[Fiction Fantasy], Genre.names.first(2)
    genres(:fantasy).move!(:up)
    assert_equal %w[Fantasy Fiction], Genre.names.first(2)
    genres(:fantasy).move!(:up) # already first: nothing happens
    assert_equal "Fantasy", Genre.names.first
    genres(:fantasy).move!(:down)
    assert_equal %w[Fiction Fantasy], Genre.names.first(2)
  end

  test "books can only have genres on the list" do
    book = Book.new(user: users(:one), title: "T", author: "A", genre: "Vampire poetry")
    assert_not book.valid?
    Genre.create!(name: "Vampire poetry")
    assert book.valid?
  end
end
