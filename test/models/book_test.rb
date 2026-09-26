require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "is valid with a title and author" do
    assert books(:hobbit).valid?
  end

  test "requires a title" do
    book = Book.new(author: "Someone")
    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "requires an author" do
    book = Book.new(title: "Something")
    assert_not book.valid?
    assert_includes book.errors[:author], "can't be blank"
  end

  test "published year is optional" do
    assert Book.new(title: "T", author: "A", published_year: nil).valid?
  end

  test "published year cannot be in the future" do
    book = Book.new(title: "T", author: "A", published_year: Date.current.year + 1)
    assert_not book.valid?
  end

  test "published year must be a whole number" do
    book = Book.new(title: "T", author: "A", published_year: 1999.5)
    assert_not book.valid?
  end
end
