require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds create an admin account" do
    User.where(email_address: "admin@bookshelf.test").destroy_all

    Rails.application.load_seed

    admin = User.find_by(email_address: "admin@bookshelf.test")
    assert admin.admin?
    assert admin.authenticate("bookshelf-admin")
  end

  test "running seeds twice does not create a second admin" do
    Rails.application.load_seed
    assert_no_difference("User.count") { Rails.application.load_seed }
  end
end
