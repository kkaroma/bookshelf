require "test_helper"

class AdminReportTest < ActiveSupport::TestCase
  setup { @report = AdminReport.new }

  test "overview counts" do
    assert_equal 3, @report.members_count
    assert_equal 2, @report.books_count
    assert_equal 1, @report.reviews_count        # The Hobbit
    assert_equal 3, @report.comments_count
    assert_equal 2, @report.ratings_count
    assert_equal 1, @report.exchange_shelf_count # Dune
    assert_equal 0, @report.books_with_cover
    assert_equal 0, @report.books_with_isbn
  end

  test "covers and ISBNs are counted" do
    books(:hobbit).cover.attach(io: file_fixture("cover.jpg").open, filename: "c.jpg", content_type: "image/jpeg")
    books(:hobbit).update!(isbn: "9780547928227")

    assert_equal 1, @report.books_with_cover
    assert_equal 1, @report.books_with_isbn
  end

  test "requests by status lists every status, including zeros" do
    assert_equal({ "pending" => 1, "accepted" => 0, "declined" => 0, "cancelled" => 0 }, @report.requests_by_status)
  end

  test "percent rounds and copes with zero" do
    assert_equal 33, @report.percent(1, 3)
    assert_equal 0, @report.percent(0, 0)
  end

  test "weekly activity covers 8 weeks, oldest first, starting on Mondays, zeros included" do
    weeks = @report.new_books_by_week

    assert_equal 8, weeks.size
    assert weeks.all? { |week| week.starts_on.monday? }
    assert_equal weeks.map(&:starts_on).sort, weeks.map(&:starts_on)
    assert_equal Time.current.beginning_of_week.to_date, weeks.last.starts_on
    assert_equal 2, weeks.last.count # both fixture books were just created
    assert_equal 2, weeks.sum(&:count)
  end

  test "weekly activity puts a record in the week it was created" do
    three_weeks_ago = 3.weeks.ago
    Book.create!(user: users(:one), title: "Old", author: "A", created_at: three_weeks_ago)
    Book.create!(user: users(:one), title: "Ancient", author: "A", created_at: 20.weeks.ago) # outside the window

    week = AdminReport.new.new_books_by_week.find { |w| w.starts_on == three_weeks_ago.beginning_of_week.to_date }
    assert_equal 1, week.count
    assert_equal 3, AdminReport.new.new_books_by_week.sum(&:count)
  end

  test "top-rated books need at least 2 ratings" do
    assert_equal [ books(:hobbit) ], @report.top_rated_books.to_a

    books(:dune).ratings.create!(user: users(:one), score: 5) # Dune now has only 1 rating
    assert_not_includes @report.top_rated_books, books(:dune)
  end

  test "most-requested books" do
    books = @report.most_requested_books
    assert_equal [ books(:dune) ], books.to_a
    assert_equal 1, books.first.requests_total
  end

  test "most active members, by books + comments + ratings" do
    members = @report.most_active_members
    # Alice: 1 book + 2 comments; Bob: 1 book + 1 comment + 1 rating; Ada: 1 rating
    assert_equal [ users(:one), users(:two), users(:admin) ], members
    assert_equal [ 2, 0 ], [ members.first.comments_total, members.first.ratings_total ]
  end

  test "members with no activity are left out" do
    User.create!(name: "Quiet", email_address: "quiet@example.com", password: "password123")
    assert_not_includes @report.most_active_members.map(&:name), "Quiet"
  end

  test "stale requests are pending ones older than 7 days" do
    request = exchange_requests(:admin_wants_dune)
    assert_empty @report.stale_requests

    request.update_column(:created_at, 8.days.ago)
    assert_equal [ request ], @report.stale_requests.to_a

    request.decline!
    assert_empty @report.stale_requests
  end

  test "latest comments come newest first" do
    newest = books(:dune).comments.create!(user: users(:two), body: "Just now")
    assert_equal newest, @report.recent_comments.first
  end

  test "books missing a cover or an ISBN" do
    assert_equal 2, @report.books_missing_details_count

    hobbit = books(:hobbit)
    hobbit.cover.attach(io: file_fixture("cover.jpg").open, filename: "c.jpg", content_type: "image/jpeg")
    assert_equal 2, @report.books_missing_details_count # still no ISBN

    hobbit.update!(isbn: "9780547928227")
    assert_equal [ books(:dune) ], @report.books_missing_details.to_a
  end
end
