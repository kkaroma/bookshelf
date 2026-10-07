require "test_helper"

class FlagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @comment = comments(:bob_on_hobbit) # by Bob, on Alice's book
    sign_in_as users(:one)              # Alice
  end

  test "the form for reporting a comment shows it and the reasons" do
    get new_flag_url(comment_id: @comment.id)
    assert_response :success
    assert_select "h1", "Report a comment"
    assert_select ".flag-quote", /#{Regexp.escape(@comment.body.first(20))}/
    assert_select "input[type=radio][name=?]", "flag[reason]", Flag::REASONS.size
  end

  test "reporting a comment" do
    assert_difference("Flag.count") do
      post flags_url(comment_id: @comment.id), params: { flag: { reason: "offensive", note: "Unkind" } }
    end

    flag = Flag.last
    assert_equal [ users(:one), @comment, "offensive", "Unkind" ], [ flag.reporter, flag.flaggable, flag.reason, flag.note ]
    assert_redirected_to book_url(@comment.book, anchor: "comment_#{@comment.id}")
    assert_equal "Thanks for letting us know. An admin will take a look.", flash[:notice]
  end

  test "reporting a book" do
    get new_flag_url(book_id: books(:dune).id)
    assert_select "h1", "Report this book"

    assert_difference("Flag.count") do
      post flags_url(book_id: books(:dune).id), params: { flag: { reason: "wrong" } }
    end
    assert_redirected_to book_url(books(:dune))
  end

  test "a report without a reason shows the form again" do
    assert_no_difference("Flag.count") do
      post flags_url(comment_id: @comment.id), params: { flag: { reason: "" } }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /Reason must be chosen/
  end

  test "reporting the same thing twice says it's already reported" do
    post flags_url(comment_id: @comment.id), params: { flag: { reason: "spam" } }
    assert_no_difference("Flag.count") do
      post flags_url(comment_id: @comment.id), params: { flag: { reason: "spam" } }
    end
    assert_select ".form-errors", /already reported/
  end

  test "can't report your own book" do
    get new_flag_url(book_id: books(:hobbit).id)
    assert_redirected_to book_url(books(:hobbit))
    assert_equal "You can't report this.", flash[:alert]
  end

  test "members see Report links on other people's things only" do
    get book_url(books(:hobbit)) # Alice's own book, Bob's comment on it
    assert_select ".report-link", count: 0
    assert_select "#comment_#{@comment.id} a[href=?]", new_flag_path(comment_id: @comment.id), "Report"
    assert_select "#comment_#{comments(:alice_reply_to_bob).id} a", text: "Report", count: 0

    get book_url(books(:dune))
    assert_select ".report-link a[href=?]", new_flag_path(book_id: books(:dune).id)
  end

  test "admins don't see Report links (they can delete things directly)" do
    sign_out
    sign_in_as users(:admin)
    get book_url(books(:hobbit))
    assert_select "a", text: "Report", count: 0
    assert_select ".report-link", count: 0
  end

  test "members must confirm their email before reporting" do
    users(:one).update_columns(email_confirmed_at: nil)
    get new_flag_url(comment_id: @comment.id)
    assert_redirected_to root_url
    assert_match(/confirm your email/, flash[:alert])
  end
end
