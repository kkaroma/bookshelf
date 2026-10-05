require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one) # password: "password"
    sign_in_as @alice
  end

  # --- Getting there ---

  test "/settings opens the profile tab" do
    get settings_url
    assert_redirected_to edit_settings_profile_path
  end

  test "settings need you to be signed in" do
    sign_out
    get edit_settings_profile_url
    assert_redirected_to new_session_url
  end

  test "every tab loads and is linked" do
    [ edit_settings_profile_path, edit_settings_password_path,
      edit_settings_notifications_path, settings_account_path ].each do |path|
      get path
      assert_response :success
      assert_select ".tabs a.active[href=?]", path
    end
  end

  test "your profile and Home link to settings" do
    get user_url(@alice)
    assert_select "a[href=?]", settings_path, text: "Settings"
    get root_url
    assert_select "a[href=?]", settings_path, text: "Account settings"
  end

  # --- Profile ---

  test "change your name" do
    patch settings_profile_url, params: { user: { name: "Alice Wonder", email_address: @alice.email_address } }
    assert_redirected_to edit_settings_profile_path
    assert_equal "Alice Wonder", @alice.reload.name
  end

  test "a blank name is rejected" do
    patch settings_profile_url, params: { user: { name: "", email_address: @alice.email_address } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /Name can't be blank/
    assert_select ".nav-user-name", "Alice Reader" # header still shows the saved name
  end

  test "changing your email needs your current password" do
    patch settings_profile_url, params: { user: { name: @alice.name, email_address: "new@example.com" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /current password to change your email/
    assert_equal "one@example.com", @alice.reload.email_address

    patch settings_profile_url, params: { user: { name: @alice.name, email_address: "new@example.com" }, current_password: "password" }
    assert_equal "new@example.com", @alice.reload.email_address
  end

  test "you can't take an email address someone else uses" do
    patch settings_profile_url, params: { user: { name: @alice.name, email_address: users(:two).email_address }, current_password: "password" }
    assert_response :unprocessable_content
    assert_select ".form-errors", /already been taken/
  end

  test "you can't change your role through the profile form" do
    patch settings_profile_url, params: { user: { name: @alice.name, email_address: @alice.email_address, role: "admin" } }
    assert @alice.reload.member?
  end

  # --- Password ---

  test "change your password, and other devices are signed out" do
    other_device = @alice.sessions.create!

    patch settings_password_url, params: { current_password: "password",
      user: { password: "brand-new-password", password_confirmation: "brand-new-password" } }

    assert_redirected_to edit_settings_password_path
    assert @alice.reload.authenticate("brand-new-password")
    assert_not Session.exists?(other_device.id)
    assert_equal 1, @alice.sessions.count # this device stays signed in
  end

  test "changing your password needs the current one" do
    patch settings_password_url, params: { current_password: "wrong",
      user: { password: "brand-new-password", password_confirmation: "brand-new-password" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /current password is incorrect/
    assert @alice.reload.authenticate("password")
  end

  test "the new password must be valid and match" do
    patch settings_password_url, params: { current_password: "password", user: { password: "", password_confirmation: "" } }
    assert_select ".form-errors", /Password can't be blank/

    patch settings_password_url, params: { current_password: "password", user: { password: "short", password_confirmation: "short" } }
    assert_select ".form-errors", /too short/

    patch settings_password_url, params: { current_password: "password", user: { password: "brand-new-password", password_confirmation: "different" } }
    assert_select ".form-errors", /doesn't match/
    assert @alice.reload.authenticate("password")
  end

  # --- Notifications ---

  test "everyone starts with all emails on" do
    get edit_settings_notifications_url
    assert_select "input[type=checkbox][name=?][checked]", "user[notify_exchange_requests]"
    assert_select "input[type=checkbox][name=?][checked]", "user[notify_comments]"
    assert_select "input[type=checkbox][name=?][checked]", "user[notify_followers]"
  end

  test "turn emails off and on" do
    patch settings_notifications_url, params: { user: { notify_exchange_requests: "1", notify_comments: "0", notify_followers: "0" } }
    assert_redirected_to edit_settings_notifications_path
    @alice.reload
    assert @alice.notify_exchange_requests?
    assert_not @alice.notify_comments?
    assert_not @alice.notify_followers?
  end

  # --- Delete account ---

  test "delete your account with your password" do
    assert_difference [ "User.count", "Book.count" ], -1 do
      delete settings_account_url, params: { password: "password" }
    end
    assert_redirected_to root_path
    assert_empty cookies[:session_id].to_s

    get books_url
    assert_redirected_to new_session_url # really signed out
  end

  test "deleting needs the right password" do
    assert_no_difference("User.count") do
      delete settings_account_url, params: { password: "wrong" }
    end
    assert_response :unprocessable_content
    assert_select ".form-errors", /password is incorrect/
  end

  test "the only admin can't delete their account" do
    sign_out
    sign_in_as users(:admin)

    get settings_account_url
    assert_select ".flash-alert", /only admin/
    assert_select "input[type=submit][value=?]", "Delete my account", count: 0

    assert_no_difference("User.count") do
      delete settings_account_url, params: { password: "password" }
    end
  end
end
