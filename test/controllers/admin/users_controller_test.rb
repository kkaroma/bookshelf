require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bob = users(:two)
    sign_in_as users(:admin)
  end

  test "lists every member with actions" do
    get admin_users_url
    assert_response :success
    assert_select ".tabs a.active", "Members"
    assert_select ".nav-main a.active", "Admin" # not the public Members page
    assert_select ".admin-member", 3
    assert_select "#user_#{@bob.id} button", text: "Make admin"
    assert_select "#user_#{@bob.id} button", text: "Suspend"
    # The only admin can't remove their own role, or be suspended.
    assert_select "#user_#{users(:admin).id} button", count: 0
  end

  test "search by name or email, and filter" do
    get admin_users_url(q: "bookworm")
    assert_select ".admin-member", 1
    assert_select ".admin-member", /two@example.com/

    get admin_users_url(show: "admins")
    assert_select ".admin-member", 1
    assert_select ".admin-member", /Ada Admin/

    @bob.update_columns(email_confirmed_at: nil)
    get admin_users_url(show: "unconfirmed")
    assert_select ".admin-member", 1
    assert_select ".admin-member .badge", "Email not confirmed"
  end

  test "search text is escaped for LIKE" do
    get admin_users_url(q: "%")
    assert_select ".admin-member", 0
  end

  test "make someone an admin, then a member again" do
    patch promote_admin_user_url(@bob)
    assert @bob.reload.admin?
    assert_equal "Bob Bookworm is now an admin.", flash[:notice]

    patch demote_admin_user_url(@bob)
    assert @bob.reload.member?
  end

  test "the last admin can't be demoted" do
    patch demote_admin_user_url(users(:admin))
    assert users(:admin).reload.admin?
    assert_match(/only admin/, flash[:alert])
  end

  test "suspend and reinstate a member" do
    bob_session = @bob.sessions.create!

    patch suspend_admin_user_url(@bob)
    assert @bob.reload.suspended?
    assert_not Session.exists?(bob_session.id)
    assert_match(/is suspended/, flash[:notice])

    patch reinstate_admin_user_url(@bob)
    assert_not @bob.reload.suspended?
  end

  test "can't suspend yourself or another admin" do
    patch suspend_admin_user_url(users(:admin))
    assert_not users(:admin).reload.suspended?
    assert_equal "You can't suspend yourself.", flash[:alert]

    @bob.admin!
    patch suspend_admin_user_url(@bob)
    assert_not @bob.reload.suspended?
    assert_match(/Remove their admin role first/, flash[:alert])
  end

  test "a suspended member can't be made admin until reinstated" do
    @bob.suspend!
    patch promote_admin_user_url(@bob)
    assert @bob.reload.member?
  end

  test "confirm an email address by hand" do
    @bob.update_columns(email_confirmed_at: nil)
    patch confirm_email_admin_user_url(@bob)
    assert @bob.reload.email_confirmed?
  end

  test "members get page not found and change nothing" do
    sign_out
    sign_in_as users(:one)
    get admin_users_url
    assert_response :not_found

    patch promote_admin_user_url(users(:one))
    assert_response :not_found
    assert users(:one).reload.member?
  end
end
