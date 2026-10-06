require "test_helper"

class BookFiltersTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @emma = @alice.books.create!(title: "Emma", author: "Jane Austen", genre: "Romance", published_year: 1815,
                                 reading_status: "read", finished_on: Date.new(2026, 1, 1), created_at: 1.day.from_now)
    books(:hobbit).update!(genre: "Fantasy", reading_status: "reading", started_on: Date.current)
    books(:dune).update!(genre: "Science fiction") # on the Exchange shelf; rated by nobody
  end

  def titles(params, allow_status: false)
    BookFilters.new(ActionController::Parameters.new(params), allow_status: allow_status).apply(Book.all).map(&:title)
  end

  test "with no choices: every book, by title" do
    assert_equal [ "Dune", "Emma", "The Hobbit" ], titles({})
    assert_not BookFilters.new(ActionController::Parameters.new({})).filtering?
  end

  test "filter by genre" do
    assert_equal [ "The Hobbit" ], titles({ genre: "Fantasy" })
  end

  test "an unknown genre or sort is ignored" do
    assert_equal 3, titles({ genre: "Vampire poetry" }).size
    assert_equal [ "Dune", "Emma", "The Hobbit" ], titles({ sort: "random" })
  end

  test "filter by reading status, only where allowed (profiles)" do
    assert_equal [ "Emma" ], titles({ status: "read" }, allow_status: true)
    assert_equal 3, titles({ status: "read" }).size # ignored on the Books page
  end

  test "exchange only" do
    assert_equal [ "Dune" ], titles({ exchange: "1" })
  end

  test "sorting" do
    assert_equal "Emma", titles({ sort: "newest" }).first
    assert_equal [ "Dune", "The Hobbit", "Emma" ], titles({ sort: "year" })      # 1965, 1937, 1815
    assert_equal "The Hobbit", titles({ sort: "rating" }).first                  # 4.5; unrated books last
  end

  test "search combines with filters" do
    assert_equal [ "Emma" ], titles({ q: "austen", genre: "Romance" })
    assert_empty titles({ q: "austen", genre: "Fantasy" })
    assert BookFilters.new(ActionController::Parameters.new(q: "austen")).filtering?
  end
end
