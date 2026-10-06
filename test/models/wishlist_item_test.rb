require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alice = users(:one)
    @bob = users(:two)      # owns Dune (already on the Exchange shelf)
    @hobbit = books(:hobbit) # Alice's, not offered
  end

  test "title is required; author and ISBN are optional and tidied" do
    assert_not @alice.wishlist_items.new(title: "").valid?
    item = @alice.wishlist_items.create!(title: "  Dune ", author: " ", isbn: "978-0-441-17271-9")
    assert_equal [ "Dune", nil, "9780441172719" ], [ item.title, item.author, item.isbn ]
    assert_not @alice.wishlist_items.new(title: "X", isbn: "123").valid?
  end

  test "available_books finds matching books on the Exchange shelf" do
    assert_equal [ books(:dune) ], @alice.wishlist_items.create!(title: "dune").available_books.to_a
    assert_equal [ books(:dune) ], @alice.wishlist_items.create!(title: "Dune", author: "frank herbert").available_books.to_a
    assert_empty @alice.wishlist_items.create!(title: "Dune", author: "Someone Else").available_books
    assert_empty @alice.wishlist_items.create!(title: "The Hobbit").available_books # not offered
  end

  test "matching by ISBN works even if the title differs" do
    books(:dune).update!(isbn: "9780441172719")
    item = @alice.wishlist_items.create!(title: "Dune: Deluxe Edition", isbn: "9780441172719")
    assert_equal [ books(:dune) ], item.available_books.to_a
  end

  test "your own books never match your wishlist" do
    @hobbit.update!(available_for_exchange: true)
    assert_empty @alice.wishlist_items.create!(title: "The Hobbit").available_books
  end

  test "offering a wished-for book alerts the member once, by bell and email" do
    @bob.wishlist_items.create!(title: "The Hobbit")
    @bob.wishlist_items.create!(title: "the hobbit", author: "J.R.R. Tolkien") # a second matching entry

    assert_enqueued_emails 1 do
      assert_difference("@bob.notifications.count", 1) { @hobbit.update!(available_for_exchange: true) }
    end
    assert_equal "wishlist_match", @bob.notifications.first.kind
    assert_equal @hobbit, @bob.notifications.first.notifiable

    # Taking it off and offering it again doesn't repeat the alert
    @hobbit.update!(available_for_exchange: false)
    assert_no_difference("@bob.notifications.count") { @hobbit.update!(available_for_exchange: true) }
  end

  test "a new book created already offered also alerts" do
    @alice.wishlist_items.create!(title: "Emma")
    assert_difference("@alice.notifications.count") do
      @bob.books.create!(title: "Emma", author: "Jane Austen", available_for_exchange: true)
    end
  end

  test "wishlist emails respect the switch (the bell still rings)" do
    @bob.update!(notify_wishlist: false)
    @bob.wishlist_items.create!(title: "The Hobbit")
    assert_no_enqueued_emails do
      assert_difference("@bob.notifications.count") { @hobbit.update!(available_for_exchange: true) }
    end
  end

  test "wishlisted? tells whether a book is on your wishlist" do
    @bob.wishlist_items.create!(title: "The Hobbit")
    assert @bob.wishlisted?(@hobbit)
    assert_not @bob.wishlisted?(books(:dune))
  end
end
