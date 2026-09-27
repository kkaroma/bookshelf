require "test_helper"

class Books::RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dune = books(:dune)     # owned by Bob (users :two), no ratings yet
    @hobbit = books(:hobbit) # owned by Alice (users :one), rated 5 by Bob and 4 by the admin
    sign_in_as users(:one)   # Alice
  end

  test "rate a book" do
    assert_difference("@dune.ratings.count") do
      put book_rating_url(@dune), params: { rating: { score: 4 } }
    end

    assert_redirected_to book_url(@dune)
    assert_equal 4, @dune.ratings.find_by(user: users(:one)).score
    assert_equal 4.0, @dune.reload.average_rating
  end

  test "rating again changes your rating instead of adding another" do
    put book_rating_url(@dune), params: { rating: { score: 2 } }

    assert_no_difference("Rating.count") do
      put book_rating_url(@dune), params: { rating: { score: 5 } }
    end
    assert_equal 5, @dune.ratings.find_by(user: users(:one)).score
  end

  test "remove your rating" do
    put book_rating_url(@dune), params: { rating: { score: 3 } }

    assert_difference("Rating.count", -1) do
      delete book_rating_url(@dune)
    end
    assert_redirected_to book_url(@dune)
    assert_equal 0, @dune.reload.ratings_count
  end

  test "removing a rating you never gave does nothing" do
    assert_no_difference("Rating.count") { delete book_rating_url(@dune) }
    assert_redirected_to book_url(@dune)
  end

  test "cannot rate your own book" do
    assert_no_difference("Rating.count") do
      put book_rating_url(@hobbit), params: { rating: { score: 5 } }
    end
    follow_redirect!
    assert_select ".flash-alert", /can't rate your own book/
  end

  test "cannot give a score outside 1 to 5" do
    assert_no_difference("Rating.count") do
      put book_rating_url(@dune), params: { rating: { score: 9 } }
    end
    follow_redirect!
    assert_select ".flash-alert", /must be between 1 and 5/
  end

  test "an admin cannot change someone else's rating" do
    sign_out
    sign_in_as users(:admin)

    put book_rating_url(@hobbit), params: { rating: { score: 1 } }
    delete book_rating_url(@hobbit)

    assert_equal 5, ratings(:bob_rates_hobbit).reload.score # Bob's rating untouched
  end

  test "signed-out visitors cannot rate" do
    sign_out
    assert_no_difference("Rating.count") do
      put book_rating_url(@dune), params: { rating: { score: 4 } }
    end
    assert_redirected_to new_session_url
  end

  # --- What the book page shows ---

  test "book page shows the average and count" do
    get book_url(@hobbit)
    assert_select ".rating-average", "4.5"
    assert_select ".rating-summary", /2 ratings/
    # 4.5 average = four full stars and a half star
    assert_select ".stars-display[aria-label=?]", "Rated 4.5 out of 5"
    assert_select ".stars-display .star-full", 4
    assert_select ".stars-display .star-half", 1
  end

  test "owner sees no stars to click, just a note" do
    get book_url(@hobbit)
    assert_select ".star-input", count: 0
    assert_select ".rate-note", /can't rate your own book/
  end

  test "other users see five star buttons" do
    get book_url(@dune)
    assert_select ".star-input button.star", 5
    assert_select ".rating-summary", /No ratings yet/
    assert_select ".rate-label", "Rate this book"
  end

  test "your current rating is highlighted and can be removed" do
    put book_rating_url(@dune), params: { rating: { score: 3 } }
    get book_url(@dune)

    assert_select ".rate-label", "Your rating"
    assert_select ".star-input button.star-on", 3
    assert_select "button", "Remove"
  end

  test "book list shows the average on each rated book" do
    get books_url
    assert_select "#book_#{@hobbit.id} .book-card-rating", /4.5/
    assert_select "#book_#{@dune.id} .book-card-rating", count: 0
  end
end
