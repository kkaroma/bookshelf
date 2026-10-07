require "test_helper"

class Admin::FlagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @comment = comments(:bob_on_hobbit)
    @flag = Flag.create!(reporter: users(:one), flaggable: @comment, reason: "offensive", note: "Rude to me")
    sign_in_as users(:admin)
  end

  test "lists reported things with their reports" do
    Flag.create!(reporter: users(:one), flaggable: books(:dune), reason: "spam")
    get admin_flags_url

    assert_response :success
    assert_select ".tabs a.active", /Reported content\s+2/
    assert_select ".flag-item", 2
    assert_select "#reported_comment_#{@comment.id} .flag-reports li", /Rude, hateful or offensive — “Rude to me”\s+· Alice Reader/
    assert_select "#reported_book_#{books(:dune).id} button", "Remove book"
  end

  test "an empty list says so" do
    @flag.destroy!
    get admin_flags_url
    assert_select ".empty-state h2", "Nothing to review"
  end

  test "dismissing keeps the comment and closes its reports" do
    patch dismiss_admin_flags_url(comment_id: @comment.id)

    assert_redirected_to admin_flags_url
    assert Comment.exists?(@comment.id)
    assert @flag.reload.resolved?
    assert_equal users(:admin), @flag.resolved_by

    follow_redirect!
    assert_select ".flag-item", 0
    assert_select ".report-section", /Recently dismissed.*Alice Reader reported/m
  end

  test "removing deletes the comment and its reports" do
    # Bob's comment has one reply, which goes with it.
    assert_difference({ "Comment.count" => -2, "Flag.count" => -1 }) do
      delete remove_admin_flags_url(comment_id: @comment.id)
    end
    assert_redirected_to admin_flags_url
    assert_equal "The comment was removed.", flash[:notice]
  end

  test "removing a reported book" do
    Flag.create!(reporter: users(:one), flaggable: books(:dune), reason: "spam")
    assert_difference("Book.count", -1) do
      delete remove_admin_flags_url(book_id: books(:dune).id)
    end
    assert_equal "The book “Dune” was removed.", flash[:notice]
  end

  test "members get page not found" do
    sign_out
    sign_in_as users(:one)
    get admin_flags_url
    assert_response :not_found
    delete remove_admin_flags_url(comment_id: @comment.id)
    assert_response :not_found
    assert Comment.exists?(@comment.id)
  end
end
