require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "is valid with a user, book and body" do
    assert comments(:bob_on_hobbit).valid?
  end

  test "requires a body" do
    comment = Comment.new(user: users(:one), book: books(:hobbit), body: "   ")
    assert_not comment.valid?
    assert_includes comment.errors[:body], "can't be blank"
  end

  test "body can be at most 2000 characters" do
    assert_not Comment.new(user: users(:one), book: books(:hobbit), body: "x" * 2001).valid?
  end

  test "strips surrounding whitespace from the body" do
    assert_equal "Nice!", Comment.new(body: "  Nice!  ").body
  end

  test "deletable by its author and admins only" do
    comment = comments(:bob_on_hobbit) # written by users(:two)
    assert comment.deletable_by?(users(:two))
    assert comment.deletable_by?(users(:admin))
    assert_not comment.deletable_by?(users(:one))
    assert_not comment.deletable_by?(nil)
  end

  test "deleting a book deletes its comments and replies" do
    assert_difference("Comment.count", -2) { books(:hobbit).destroy }
  end

  test "deleting a user deletes their comments" do
    # users(:two) wrote one comment (which has one reply), and owns Dune, which has one comment
    assert_difference("Comment.count", -3) { users(:two).destroy }
  end

  # --- Replies ---

  test "a reply belongs to its parent comment" do
    reply = comments(:alice_reply_to_bob)
    assert reply.reply?
    assert_equal comments(:bob_on_hobbit), reply.parent
    assert_includes comments(:bob_on_hobbit).replies, reply
  end

  test "top_level excludes replies" do
    assert_includes Comment.top_level, comments(:bob_on_hobbit)
    assert_not_includes Comment.top_level, comments(:alice_reply_to_bob)
  end

  test "replying to a reply joins the original thread" do
    reply = comments(:alice_reply_to_bob)
    answer = Comment.create!(user: users(:two), book: books(:hobbit), parent: reply, body: "@Alice Reader yes!")

    assert_equal comments(:bob_on_hobbit), answer.parent
    assert_equal comments(:bob_on_hobbit), answer.thread_root
  end

  test "a reply must be on the same book as its parent" do
    comment = Comment.new(user: users(:one), book: books(:dune), parent: comments(:bob_on_hobbit), body: "Hi")
    assert_not comment.valid?
    assert_includes comment.errors[:parent], "must be a comment on this book"
  end

  test "replies are listed oldest first" do
    parent = comments(:bob_on_hobbit)
    later = parent.replies.create!(user: users(:two), book: parent.book, body: "Later reply")
    assert_equal later, parent.replies.last
  end
end
