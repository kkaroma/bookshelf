require "test_helper"

class MemberJourneyTest < ActiveSupport::TestCase
  def new_member(name, confirmed: true)
    User.create!(name: name, email_address: "#{name.downcase}@example.com", password: "password123").tap do |user|
      user.update_columns(email_confirmed_at: (Time.current if confirmed))
    end
  end

  setup do
    # Fixture members joined "now" too, so look only at members created here.
    User.update_all(created_at: 1.year.ago)
  end

  # Built after the test's members exist: a report covers up to the moment it's made.
  def journey = MemberJourney.new

  test "counts how far newcomers got" do
    new_member("Unsure", confirmed: false)
    new_member("Browser")
    reader = new_member("Reader")
    Book.create!(user: reader, title: "Emma", author: "Jane Austen")

    steps = journey.steps.to_h { |step| [ step.key, step.count ] }
    assert_equal({ joined: 3, confirmed: 2, book: 1, checklist: 0, swap: 0 }, steps)
    assert_equal 67, journey.percent(journey.steps.second)
  end

  test "finishing the checklist and completing a swap" do
    keen = new_member("Keen")
    book = Book.create!(user: keen, title: "Emma", author: "Jane Austen", review: "Lovely", available_for_exchange: true)
    book.cover.attach(io: file_fixture("cover.jpg").open, filename: "cover.jpg", content_type: "image/jpeg")
    keen.follow(users(:one))
    request = ExchangeRequest.create!(requester: keen, book: books(:dune))
    request.update_columns(status: ExchangeRequest.statuses[:completed], completed_at: Time.current)

    steps = journey.steps.to_h { |step| [ step.key, step.count ] }
    assert_equal 1, steps[:checklist]
    assert_equal 1, steps[:swap]
  end

  test "who might need a nudge" do
    new_member("Unsure", confirmed: false)
    browser = new_member("Browser")

    assert_equal 1, journey.unconfirmed_count
    assert_equal [ browser ], journey.no_books_yet.to_a
  end

  test "only members who joined in the period count" do
    assert_equal 0, journey.joined_count
    assert_equal 3, MemberJourney.new(period: ReportPeriod.new("all")).joined_count
  end

  test "the CSV lists every step" do
    new_member("Browser")
    rows = CSV.parse(journey.to_csv)
    assert_includes rows, [ "Journey", "Signed up", "1" ]
    assert_includes rows, [ "Journey (% of those who joined)", "Confirmed their email", "100" ]
  end
end
