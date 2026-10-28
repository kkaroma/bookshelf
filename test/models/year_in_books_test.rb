require "test_helper"

class YearInBooksTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    travel_to Time.zone.local(2026, 11, 15, 12)
  end

  def read_book(title, finished:, started: nil, genre: nil)
    Book.create!(user: @alice, title: title, author: "Someone", genre: genre,
                 reading_status: :read, started_on: started, finished_on: finished)
  end

  test "books read in the year, month by month" do
    read_book("Emma", finished: Date.new(2026, 3, 2), genre: "Fiction")
    read_book("Persuasion", finished: Date.new(2026, 3, 20), genre: "Fiction")
    read_book("Sapiens", finished: Date.new(2026, 7, 1), genre: "History")
    read_book("Old one", finished: Date.new(2025, 12, 31))

    year = YearInBooks.new(@alice, 2026)
    assert_equal %w[Emma Persuasion Sapiens], year.books_read.map(&:title)
    assert_equal "January 2026", year.by_month.first.long_label
    assert_equal 2, year.by_month.find { |bar| bar.short_label == "Mar" }.count
    assert_equal "March 2026", year.busiest_month.long_label
    assert_equal({ "Fiction" => 2, "History" => 1 }, year.top_genres)
    assert_equal [ 2026, 2025 ], year.available_years
  end

  test "the quickest read needs both dates" do
    read_book("Slow", started: Date.new(2026, 1, 1), finished: Date.new(2026, 2, 1))
    read_book("Fast", started: Date.new(2026, 4, 1), finished: Date.new(2026, 4, 3))
    read_book("No start", finished: Date.new(2026, 5, 1))

    assert_equal "Fast", YearInBooks.new(@alice, 2026).quickest_read.title
  end

  test "ratings, reviews, comments and the reading goal" do
    @alice.reading_goals.create!(year: 2026, target: 10)
    read_book("Emma", finished: Date.new(2026, 3, 2))
    Rating.create!(user: @alice, book: books(:dune), score: 4)
    @alice.comments.update_all(created_at: 2.years.ago) # the fixtures' comments
    Comment.create!(user: @alice, book: books(:dune), body: "Great")

    year = YearInBooks.new(@alice, 2026)
    assert_equal 1, year.goal.progress
    assert_equal 1, year.ratings.count
    assert_equal books(:dune), year.favourite_rating.book
    assert_equal 1, year.comments_written
    assert year.anything?
  end

  test "swaps show what you got and gave, and with whom" do
    request = ExchangeRequest.create!(requester: @alice, book: books(:dune), offered_book: books(:hobbit))
    request.update_columns(status: ExchangeRequest.statuses[:completed], completed_at: Time.current)

    swap = YearInBooks.new(@alice, 2026).swaps.sole
    assert_equal books(:dune), swap.received
    assert_equal books(:hobbit), swap.gave
    assert_equal users(:two), swap.with

    bobs = YearInBooks.new(users(:two), 2026).swaps.sole
    assert_equal books(:hobbit), bobs.received
    assert_equal @alice, bobs.with
  end

  test "an empty year" do
    year = YearInBooks.new(users(:admin), 2019)
    assert_equal 0, year.read_count
    assert_nil year.busiest_month
    assert_not year.anything?
  end

  test "received books link to your own copy, and books read before swapping still count" do
    read_book("Emma", finished: Date.new(2026, 3, 2)).hand_over_to!(users(:two)) # read it, then swapped it away
    request = ExchangeRequest.create!(requester: @alice, book: books(:dune))
    request.update_columns(status: ExchangeRequest.statuses[:accepted])
    request.complete!(by: @alice)

    year = YearInBooks.new(@alice, 2026)
    assert_includes year.books_read.map(&:title), "Emma"
    assert_equal @alice, year.swaps.sole.received.user # Alice's new copy, not Bob's old one
  end
end
