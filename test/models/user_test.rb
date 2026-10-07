require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def build_user(**attributes)
    User.new({ name: "Carol", email_address: "carol@example.com", password: "secret-password" }.merge(attributes))
  end

  test "is valid with a name, email and password" do
    assert build_user.valid?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "strips whitespace from name" do
    assert_equal "Carol", build_user(name: "  Carol  ").name
  end

  test "requires a name" do
    user = build_user(name: "")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires a valid email address" do
    assert_not build_user(email_address: "not-an-email").valid?
  end

  test "requires a unique email address, ignoring case" do
    user = build_user(email_address: users(:one).email_address.upcase)
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "requires a password of at least 8 characters" do
    user = build_user(password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "requires the password confirmation to match" do
    assert_not build_user(password_confirmation: "something-else").valid?
  end

  test "new users are members by default" do
    user = build_user
    assert user.member?
    assert_not user.admin?
  end

  test "a user can be made an admin" do
    user = users(:one)
    user.admin!
    assert user.reload.admin?
  end

  test "last_admin? is true only for the site's only admin" do
    assert users(:admin).last_admin?
    assert_not users(:one).last_admin?

    users(:one).admin!
    assert_not users(:admin).last_admin?
  end

  test "city is optional and tidied up" do
    assert_nil build_user(city: "   ").tap(&:valid?).city
    assert_equal "Dar es Salaam", build_user(city: "  Dar   es Salaam ").city
    assert_not build_user(city: "x" * 61).valid?
  end

  test "same_city_as? ignores capital letters" do
    a = build_user(city: "Dar es Salaam")
    assert a.same_city_as?(build_user(city: "dar es salaam"))
    assert_not a.same_city_as?(build_user(city: "Arusha"))
    assert_not a.same_city_as?(build_user(city: nil))
    assert_not build_user(city: nil).same_city_as?(build_user(city: nil))
  end

  test "rejects an unknown role" do
    assert_not build_user(role: "superhero").valid?
  end

  # --- Email confirmation ---

  test "new accounts are unconfirmed and get a confirmation email" do
    assert_enqueued_email_with AccountMailer, :email_confirmation, args: ->(args) { args.first.email_address == "new@example.com" } do
      @new_user = build_user(email_address: "new@example.com").tap(&:save!)
    end
    assert_not @new_user.email_confirmed?
  end

  test "the confirmation link's token finds the member, until the email changes" do
    user = users(:one)
    token = user.generate_token_for(:email_confirmation)
    assert_equal user, User.find_by_token_for(:email_confirmation, token)

    user.update!(email_address: "alice.new@example.com")
    assert_nil User.find_by_token_for(:email_confirmation, token)
  end

  test "the confirmation link expires after 3 days" do
    token = users(:one).generate_token_for(:email_confirmation)
    travel 3.days + 1.minute
    assert_nil User.find_by_token_for(:email_confirmation, token)
  end

  test "changing the email address needs confirming again and sends a new email" do
    user = users(:one)
    assert user.email_confirmed?

    assert_enqueued_email_with AccountMailer, :email_confirmation, args: [ user ] do
      user.update!(email_address: "alice.new@example.com")
    end
    assert_not user.email_confirmed?
  end

  test "other changes keep the email confirmed and send nothing" do
    user = users(:one)
    assert_no_enqueued_emails { user.update!(name: "Alice R.") }
    assert user.email_confirmed?
  end

  test "confirm_email! confirms" do
    user = users(:one)
    user.update_columns(email_confirmed_at: nil)
    user.confirm_email!
    assert user.reload.email_confirmed?
  end

  # --- Suspension ---

  test "suspending signs the member out and hides them from active members" do
    bob = users(:two)
    bob.sessions.create!

    bob.suspend!

    assert bob.suspended?
    assert_empty bob.sessions.reload
    assert_not_includes User.active, bob
  end

  test "suspending takes their books off the Exchange shelf, declining requests for them" do
    bob = users(:two)
    request = exchange_requests(:admin_wants_dune)

    bob.suspend!

    assert_not books(:dune).reload.available_for_exchange?
    assert request.reload.declined?
  end

  test "suspending cancels the requests they sent" do
    request = exchange_requests(:admin_wants_dune) # sent by the admin
    users(:admin).update!(role: :member)

    users(:admin).suspend!
    assert request.reload.cancelled?
  end

  test "admins can't be suspended" do
    assert_not users(:admin).suspendable?
    assert_raises(ArgumentError) { users(:admin).suspend! }
  end

  test "reinstating lets them back in" do
    bob = users(:two)
    bob.suspend!
    bob.reinstate!
    assert_not bob.suspended?
    assert_includes User.active, bob
  end
end
