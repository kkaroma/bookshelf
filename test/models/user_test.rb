require "test_helper"

class UserTest < ActiveSupport::TestCase
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
end
