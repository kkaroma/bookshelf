require "test_helper"

class GettingStartedTest < ActiveSupport::TestCase
  setup do
    @newbie = User.create!(name: "Nora New", email_address: "nora@example.com", password: "password123")
  end

  def done(user) = GettingStarted.new(user).steps.select(&:done).map(&:key)

  test "a brand-new member has done nothing yet" do
    checklist = GettingStarted.new(@newbie)
    assert_equal 0, checklist.done_count
    assert_equal 5, checklist.steps.size
    assert_not checklist.complete?
  end

  test "steps tick off as the member uses the site" do
    book = @newbie.books.create!(title: "Emma", author: "Jane Austen")
    assert_equal [ :add_book ], done(@newbie.reload)

    book.cover.attach(io: file_fixture("cover.jpg").open, filename: "cover.jpg", content_type: "image/jpeg")
    book.update!(review: "Witty!", available_for_exchange: true)
    @newbie.follow(users(:one))

    assert_equal %i[ add_book add_cover review follow exchange ], done(@newbie.reload)
    assert GettingStarted.new(@newbie).complete?
  end

  test "points each step at a book that still needs it" do
    first  = @newbie.books.create!(title: "First", author: "A", review: "Done")
    second = @newbie.books.create!(title: "Second", author: "B")
    checklist = GettingStarted.new(@newbie)

    assert_equal first, checklist.book_for(:add_cover)
    assert_equal second, checklist.book_for(:review)
    assert_equal first, checklist.book_for(:exchange)
  end
end
