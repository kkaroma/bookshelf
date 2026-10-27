require "test_helper"

class SwapReportTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)  # owns The Hobbit
    @bob = users(:two)    # owns Dune (on the shelf; the admin has a pending request for it)
    @report = SwapReport.new
  end

  def new_request(book:, from:, status: :pending, created: 2.days.ago, answered_after: nil)
    request = travel_to(created) { ExchangeRequest.create!(requester: from, book: book) }
    if answered_after
      request.update_columns(status: ExchangeRequest.statuses[status], responded_at: created + answered_after,
                             completed_at: (created + answered_after if status == :completed))
    end
    request
  end

  test "requests in the period, by result" do
    books(:hobbit).update!(available_for_exchange: true)
    new_request(book: books(:hobbit), from: @bob, status: :declined, answered_after: 2.hours)
    new_request(book: books(:hobbit), from: users(:admin), created: 6.months.ago) # outside the last 3 months

    assert_equal 2, @report.requests_count # the fixture's pending one + the declined one
    assert_equal 1, @report.requests_by_status["pending"]
    assert_equal 1, @report.requests_by_status["declined"]
    assert_equal 0, @report.requests_by_status["completed"]
    assert_equal 3, SwapReport.new(period: ReportPeriod.new("12m")).requests_count
  end

  test "acceptance rate counts only answered requests" do
    assert_nil @report.acceptance_rate # only a pending one so far

    books(:hobbit).update!(available_for_exchange: true)
    new_request(book: books(:hobbit), from: @bob, status: :accepted, answered_after: 1.hour)
    other = Book.create!(user: @alice, title: "Emma", author: "Jane Austen", available_for_exchange: true)
    new_request(book: other, from: @bob, status: :completed, answered_after: 3.hours)
    third = Book.create!(user: @alice, title: "Persuasion", author: "Jane Austen", available_for_exchange: true)
    new_request(book: third, from: @bob, status: :declined, answered_after: 5.hours)

    assert_equal 67, @report.acceptance_rate # 2 of 3 answered said yes
    assert_in_delta 3.hours.to_f, @report.median_answer_seconds, 1
    assert_equal 1, @report.completed_count
  end

  test "requests and completed swaps month by month" do
    books(:hobbit).update!(available_for_exchange: true)
    new_request(book: books(:hobbit), from: @bob, status: :completed, answered_after: 1.day, created: 5.days.ago)

    assert_equal 12, @report.requests_by_month.size
    assert_equal 2, @report.requests_by_month.sum(&:count)
    assert_equal 1, @report.completed_by_month.sum(&:count)
  end

  test "most wanted books, grouped by title, with copies on the shelf" do
    carol = User.create!(name: "Carol", email_address: "carol@example.com", password: "password123")
    WishlistItem.create!(user: @alice, title: "Dune", author: "Frank Herbert")
    WishlistItem.create!(user: carol, title: "dune")
    WishlistItem.create!(user: carol, title: "Middlemarch", author: "George Eliot")

    wanted = @report.most_wanted
    assert_equal [ 2, 1 ], wanted.map(&:wanted_by)
    assert_equal "Dune", wanted.first.title
    assert_equal 1, wanted.first.on_shelf # Bob's copy
    assert_equal 0, wanted.last.on_shelf  # nobody offers Middlemarch
  end

  test "books on the shelf nobody has asked for since they were listed" do
    assert_empty @report.unrequested_books # Dune has the admin's request

    travel_to(20.days.ago) { books(:hobbit).update!(available_for_exchange: true) }
    assert_equal [ books(:hobbit) ], @report.unrequested_books.to_a
    assert_equal 20, (Date.current - SwapReport.listed_at(books(:hobbit).reload).to_date).to_i
  end

  test "the CSV has the headline numbers" do
    rows = CSV.parse(@report.to_csv)
    assert_includes rows, [ "Report", "Period", "Last 3 months" ]
    assert_includes rows, [ "Requests", "Requests made", "1" ]
    assert_equal 12, rows.count { |row| row[0] == "Requests per month" }
  end
end
