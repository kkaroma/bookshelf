require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:hobbit)
    @bobs_comment = comments(:bob_on_hobbit) # users(:two) on users(:one)'s book
    sign_in_as users(:one)
  end

  test "book page lists comments and the comment form" do
    get book_url(@book)
    assert_select "#comments_count", "2" # one comment + one reply
    assert_select "#comments_list > .comment-thread", 1
    assert_select ".comment", /Loved your take/
    assert_select ".replies .comment-reply", /that chapter is my favourite/
    assert_select "form#new_comment textarea[name=?]", "comment[body]"
  end

  test "book owner's comments are marked as Owner" do
    get book_url(@book)
    assert_select ".comment-reply .badge", "Owner" # Alice's reply on her own book
  end

  test "create adds a comment by the signed-in user" do
    assert_difference("@book.comments.count") do
      post book_comments_url(@book), params: { comment: { body: "Great review!" } }
    end

    comment = @book.comments.last
    assert_equal users(:one), comment.user
    assert_equal "Great review!", comment.body
    assert_redirected_to book_url(@book, anchor: "comments")
  end

  test "create with Turbo returns stream updates instead of a redirect" do
    post book_comments_url(@book), params: { comment: { body: "Great review!" } }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=comments_list]"
    assert_select "turbo-stream[action=update][target=comments_count]"
    assert_select "turbo-stream[action=replace][target=new_comment]"
  end

  test "create ignores an attempt to post as someone else" do
    post book_comments_url(@book), params: { comment: { body: "Hi", user_id: users(:two).id } }
    assert_equal users(:one), @book.comments.last.user
  end

  test "create with a blank comment saves nothing and shows the error" do
    assert_no_difference("Comment.count") do
      post book_comments_url(@book), params: { comment: { body: "" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new_comment]"
    assert_match "Body can&#39;t be blank", response.body
  end

  test "you can comment on someone else's book" do
    assert_difference("Comment.count") do
      post book_comments_url(books(:dune)), params: { comment: { body: "Adding this to my list." } }
    end
  end

  test "author can delete their own comment" do
    mine = @book.comments.create!(user: users(:one), body: "Oops")

    assert_difference("Comment.count", -1) do
      delete book_comment_url(@book, mine), as: :turbo_stream
    end
    assert_select "turbo-stream[action=remove][target=?]", "thread_comment_#{mine.id}"
  end

  test "cannot delete someone else's comment, even on your own book" do
    assert_no_difference("Comment.count") do
      delete book_comment_url(@book, @bobs_comment)
    end
    assert_redirected_to book_url(@book)
  end

  test "delete button shows only on comments you can delete" do
    get book_url(@book)
    # Alice wrote the reply, not Bob's comment above it
    assert_select ".comment button", text: "Delete", count: 1
    assert_select ".comment-reply button", text: "Delete", count: 1
  end

  # --- Replies ---

  test "every comment has a reply button and each thread has a hidden reply form" do
    get book_url(@book)
    assert_select ".comment button", text: "Reply", count: 2
    assert_select "form[id=?][hidden]", "reply_form_comment_#{@bobs_comment.id}"
    assert_select "form[id=?] input[type=hidden][name=?][value=?]",
                  "reply_form_comment_#{@bobs_comment.id}", "comment[parent_id]", @bobs_comment.id.to_s
  end

  test "replying to a reply prefills a mention of that person" do
    get book_url(@book)
    assert_select ".comment-reply button[data-reply-mention-param=?]", "Alice Reader"
  end

  test "create a reply" do
    assert_difference("@bobs_comment.replies.count") do
      post book_comments_url(@book), params: { comment: { body: "Me too!", parent_id: @bobs_comment.id } }
    end
    assert_equal users(:one), @bobs_comment.replies.last.user
  end

  test "create a reply with Turbo adds it to the thread" do
    post book_comments_url(@book), params: { comment: { body: "Me too!", parent_id: @bobs_comment.id } }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=?]", "replies_comment_#{@bobs_comment.id}"
    assert_select "turbo-stream[action=replace][target=?]", "reply_form_comment_#{@bobs_comment.id}"
    assert_select "turbo-stream[action=update][target=comments_count]"
    assert_select "turbo-stream[target=comments_list]", count: 0
  end

  test "a reply to a reply joins the same thread" do
    reply = comments(:alice_reply_to_bob)
    post book_comments_url(@book), params: { comment: { body: "@Alice Reader agreed", parent_id: reply.id } }

    assert_equal @bobs_comment, Comment.last.parent
  end

  test "a blank reply shows the error inside the open reply form" do
    assert_no_difference("Comment.count") do
      post book_comments_url(@book), params: { comment: { body: "", parent_id: @bobs_comment.id } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?]", "reply_form_comment_#{@bobs_comment.id}"
    assert_match "Body can&#39;t be blank", response.body
    assert_no_match(/<form[^>]*hidden/, response.body)
  end

  test "cannot reply to a comment on a different book" do
    assert_no_difference("Comment.count") do
      post book_comments_url(books(:dune)), params: { comment: { body: "Sneaky", parent_id: @bobs_comment.id } }
    end
  end

  test "deleting a reply removes only that reply" do
    reply = comments(:alice_reply_to_bob)

    assert_difference("Comment.count", -1) do
      delete book_comment_url(@book, reply), as: :turbo_stream
    end
    assert_select "turbo-stream[action=remove][target=?]", "comment_#{reply.id}"
  end

  test "deleting a comment also deletes its replies" do
    sign_out
    sign_in_as users(:two) # Bob

    assert_difference("Comment.count", -2) do
      delete book_comment_url(@book, @bobs_comment)
    end
  end

  test "admin can delete any comment" do
    sign_out
    sign_in_as users(:admin)

    assert_difference("Comment.count", -2) do # Bob's comment and the reply under it
      delete book_comment_url(@book, @bobs_comment)
    end
  end

  test "signed-out visitors cannot comment" do
    sign_out
    assert_no_difference("Comment.count") do
      post book_comments_url(@book), params: { comment: { body: "Hi" } }
    end
    assert_redirected_to new_session_url
  end
end
