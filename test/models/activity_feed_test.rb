require "test_helper"

class ActivityFeedTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @bob = users(:two)      # follows Alice
    @admin = users(:admin)  # follows nobody
  end

  def kinds(user) = ActivityFeed.new(user).events.map(&:kind)

  test "shows books added by people you follow" do
    event = ActivityFeed.new(@bob).events.find { |e| e.kind == :added }
    assert_equal @alice, event.actor
    assert_equal books(:hobbit), event.book
  end

  test "reviews, ratings and completed swaps appear too, newest first" do
    travel_to(3.days.ago) { books(:hobbit).update!(review: "Changed my mind - it's wonderful.") }
    emma = @admin.books.create!(title: "Emma", author: "Jane Austen")
    # (Not Dune: the swap below makes Alice Dune's owner, and owners' ratings of their own books are removed.)
    travel_to(2.days.ago) { emma.ratings.create!(user: @alice, score: 4) }
    request = ExchangeRequest.create!(requester: @alice, book: books(:dune))
    request.accept!
    travel_to(1.day.ago) { request.complete!(by: @bob) }

    events = ActivityFeed.new(@bob).events
    # (The sample books were "added" just now, so those events come first.)
    assert_equal %i[ swapped rated reviewed ], events.map(&:kind).without(:added)
    assert_equal "Changed my mind - it's wonderful.", events.find { |e| e.kind == :reviewed }.detail
    assert_equal 4, events.find { |e| e.kind == :rated }.detail
    assert_equal @bob, events.find { |e| e.kind == :swapped }.detail # the other person in the swap
  end

  test "nothing from people you don't follow" do
    assert_empty kinds(@admin)
  end

  test "writing or clearing a review sets reviewed_at" do
    book = books(:dune)
    book.update!(review: "Great")
    assert book.reviewed_at.present?
    book.update!(review: "")
    assert_nil book.reviewed_at
  end
end
