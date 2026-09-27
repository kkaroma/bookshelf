require "test_helper"

class RatingTest < ActiveSupport::TestCase
  test "is valid with a score from 1 to 5" do
    (1..5).each do |score|
      assert Rating.new(user: users(:one), book: books(:dune), score: score).valid?, "score #{score} should be valid"
    end
  end

  test "rejects scores outside 1 to 5" do
    [ 0, 6, nil ].each do |score|
      assert_not Rating.new(user: users(:one), book: books(:dune), score: score).valid?, "score #{score.inspect} should be invalid"
    end
  end

  test "one rating per user per book" do
    duplicate = Rating.new(user: users(:two), book: books(:hobbit), score: 3)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already rated this book"
  end

  test "the database also refuses a duplicate rating" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Rating.insert!({ user_id: users(:two).id, book_id: books(:hobbit).id, score: 1 })
    end
  end

  test "you cannot rate your own book" do
    rating = Rating.new(user: users(:one), book: books(:hobbit), score: 5) # Alice owns The Hobbit
    assert_not rating.valid?
    assert_includes rating.errors[:base], "You can't rate your own book"
  end

  test "adding a rating updates the book's average and count" do
    dune = books(:dune)
    dune.ratings.create!(user: users(:one), score: 4)
    dune.ratings.create!(user: users(:admin), score: 3)

    dune.reload
    assert_equal 2, dune.ratings_count
    assert_equal 3.5, dune.average_rating
  end

  test "changing a rating updates the average" do
    ratings(:bob_rates_hobbit).update!(score: 2) # scores now 2 and 4
    assert_equal 3.0, books(:hobbit).reload.average_rating
  end

  test "removing ratings updates the average and count" do
    ratings(:bob_rates_hobbit).destroy
    hobbit = books(:hobbit).reload
    assert_equal 1, hobbit.ratings_count
    assert_equal 4.0, hobbit.average_rating

    ratings(:admin_rates_hobbit).destroy
    hobbit.reload
    assert_equal 0, hobbit.ratings_count
    assert_nil hobbit.average_rating
  end

  test "average is rounded to one decimal place" do
    dune = books(:dune)
    dune.ratings.create!(user: users(:one), score: 5)
    dune.ratings.create!(user: users(:admin), score: 4)
    Rating.create!(user: User.create!(name: "Cy", email_address: "cy@example.com", password: "password123"), book: dune, score: 4)
    assert_equal 4.3, dune.reload.average_rating # 13 / 3 = 4.333…
  end

  test "deleting a book or a user deletes their ratings" do
    assert_difference("Rating.count", -2) { books(:hobbit).destroy }
    assert_difference("Rating.count", 0) { users(:one).destroy } # Alice has no ratings left
  end
end
