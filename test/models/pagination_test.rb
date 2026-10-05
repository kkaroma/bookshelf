require "test_helper"

class PaginationTest < ActiveSupport::TestCase
  setup do
    30.times { |i| Book.create!(user: users(:one), title: format("Book %02d", i), author: "A") }
    @scope = Book.order(:title) # 32 books (2 fixtures + 30)
  end

  test "splits a list into pages" do
    pagination = Pagination.new(@scope, page: 2, per_page: 10)

    assert_equal 32, pagination.total_count
    assert_equal 4, pagination.total_pages
    assert_equal 10, pagination.records.size
    assert_equal @scope.offset(10).first, pagination.records.first
    assert_equal [ 11, 20 ], [ pagination.first_item, pagination.last_item ]
  end

  test "previous and next pages" do
    first = Pagination.new(@scope, page: 1, per_page: 10)
    assert_nil first.previous_page
    assert_equal 2, first.next_page

    last = Pagination.new(@scope, page: 4, per_page: 10)
    assert_equal 3, last.previous_page
    assert_nil last.next_page
    assert_equal [ 31, 32 ], [ last.first_item, last.last_item ]
  end

  test "missing, junk or out-of-range page numbers go to the nearest real page" do
    assert_equal 1, Pagination.new(@scope, page: nil, per_page: 10).page
    assert_equal 1, Pagination.new(@scope, page: "abc", per_page: 10).page
    assert_equal 1, Pagination.new(@scope, page: -3, per_page: 10).page
    assert_equal 4, Pagination.new(@scope, page: 99, per_page: 10).page
  end

  test "an empty list is one empty page" do
    pagination = Pagination.new(Book.none, page: 1, per_page: 10)
    assert_equal 1, pagination.total_pages
    assert_not pagination.multiple_pages?
    assert_equal [ 0, 0 ], [ pagination.first_item, pagination.last_item ]
  end
end
