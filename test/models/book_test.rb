require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "is valid with a title and author" do
    assert books(:hobbit).valid?
  end

  test "requires an owner" do
    book = Book.new(title: "T", author: "A")
    assert_not book.valid?
    assert_includes book.errors[:user], "must exist"
  end

  test "owned_by? is true only for the book's owner" do
    assert books(:hobbit).owned_by?(users(:one))
    assert_not books(:hobbit).owned_by?(users(:two))
    assert_not books(:hobbit).owned_by?(nil)
  end

  test "editable_by? allows the owner and admins only" do
    book = books(:hobbit)
    assert book.editable_by?(users(:one))
    assert book.editable_by?(users(:admin))
    assert_not book.editable_by?(users(:two))
    assert_not book.editable_by?(nil)
  end

  test "rateable_by? allows anyone signed in except the owner" do
    book = books(:hobbit)
    assert book.rateable_by?(users(:two))
    assert book.rateable_by?(users(:admin))
    assert_not book.rateable_by?(users(:one))
    assert_not book.rateable_by?(nil)
  end

  test "deleting a user deletes their books" do
    assert_difference("Book.count", -1) { users(:one).destroy }
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

  test "subtitle and review are optional" do
    assert Book.new(user: users(:one), title: "T", author: "A", subtitle: nil, review: nil).valid?
  end

  test "a review of only spaces is saved as no review" do
    book = books(:hobbit)
    book.update!(review: "   ")
    assert_nil book.review
  end

  test "subtitle can be at most 200 characters" do
    assert Book.new(user: users(:one), title: "T", author: "A", subtitle: "x" * 200).valid?
    assert_not Book.new(user: users(:one), title: "T", author: "A", subtitle: "x" * 201).valid?
  end

  test "published year is optional" do
    assert Book.new(user: users(:one), title: "T", author: "A", published_year: nil).valid?
  end

  test "published year cannot be in the future" do
    book = Book.new(user: users(:one), title: "T", author: "A", published_year: Date.current.year + 1)
    assert_not book.valid?
  end

  test "published year must be a whole number" do
    book = Book.new(user: users(:one), title: "T", author: "A", published_year: 1999.5)
    assert_not book.valid?
  end
end
