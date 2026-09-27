require "test_helper"

class FollowTest < ActiveSupport::TestCase
  setup do
    @alice = users(:one)
    @bob   = users(:two)   # already follows Alice
    @admin = users(:admin)
  end

  test "following and followers work from both sides" do
    assert_includes @bob.following, @alice
    assert_includes @alice.followers, @bob
    assert_empty @alice.following
  end

  test "follow adds someone and updates both counters" do
    @alice.follow(@bob)

    assert @alice.following?(@bob)
    assert_equal 1, @alice.reload.following_count
    assert_equal 1, @bob.reload.followers_count
  end

  test "unfollow removes them and updates both counters" do
    @bob.unfollow(@alice)

    assert_not @bob.following?(@alice)
    assert_equal 0, @bob.reload.following_count
    assert_equal 0, @alice.reload.followers_count
  end

  test "following? reflects follow and unfollow straight away" do
    assert_not @admin.following?(@alice)
    @admin.follow(@alice)
    assert @admin.following?(@alice)
    @admin.unfollow(@alice)
    assert_not @admin.following?(@alice)
  end

  test "cannot follow yourself" do
    follow = Follow.new(follower: @alice, followed: @alice)
    assert_not follow.valid?
    assert_includes follow.errors[:base], "You can't follow yourself"
  end

  test "cannot follow the same person twice" do
    duplicate = Follow.new(follower: @bob, followed: @alice)
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordInvalid) { @bob.follow(@alice) }
  end

  test "the database also refuses a duplicate follow" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Follow.insert!({ follower_id: @bob.id, followed_id: @alice.id })
    end
  end

  test "deleting a user removes their follows and fixes the other person's count" do
    assert_difference("Follow.count", -1) { @bob.destroy }
    assert_equal 0, @alice.reload.followers_count
  end

  test "books_count counts a user's books" do
    assert_difference("@alice.reload.books_count", 1) do
      @alice.books.create!(title: "Emma", author: "Jane Austen")
    end
    assert_difference("@alice.reload.books_count", -1) do
      @alice.books.last.destroy
    end
  end
end
