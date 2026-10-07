require "test_helper"

class FlagTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alice = users(:one)              # owns The Hobbit
    @bob_comment = comments(:bob_on_hobbit)
  end

  test "a member can report someone else's comment or book" do
    assert Flag.new(reporter: @alice, flaggable: @bob_comment, reason: "offensive").valid?
    assert Flag.new(reporter: @alice, flaggable: books(:dune), reason: "spam").valid?
  end

  test "needs a known reason" do
    flag = Flag.new(reporter: @alice, flaggable: @bob_comment, reason: "boring")
    assert_not flag.valid?
    assert_includes flag.errors[:reason], "must be chosen"
  end

  test "“Something else” needs a note" do
    flag = Flag.new(reporter: @alice, flaggable: @bob_comment, reason: "other", note: "  ")
    assert_not flag.valid?
    assert flag.errors[:note].any?

    flag.note = "Contains someone's phone number"
    assert flag.valid?
  end

  test "nobody reports their own things, and admins don't report at all" do
    assert_not Flag.new(reporter: @alice, flaggable: books(:hobbit), reason: "spam").valid?
    assert_not Flag.new(reporter: users(:admin), flaggable: @bob_comment, reason: "spam").valid?
  end

  test "one open report per member per thing; again allowed once dismissed" do
    Flag.create!(reporter: @alice, flaggable: @bob_comment, reason: "spam")
    duplicate = Flag.new(reporter: @alice, flaggable: @bob_comment, reason: "offensive")
    assert_not duplicate.valid?
    assert_match(/already reported/, duplicate.errors.full_messages.to_sentence)

    Flag.dismiss_all_for(@bob_comment, by: users(:admin))
    assert duplicate.valid?
  end

  test "the database also allows only one open report per member per thing" do
    Flag.create!(reporter: @alice, flaggable: @bob_comment, reason: "spam")
    assert_raises(ActiveRecord::RecordNotUnique) do
      Flag.new(reporter: @alice, flaggable: @bob_comment, reason: "spam").save!(validate: false)
    end
  end

  test "reporting tells every active admin, in the app and by email" do
    second_admin = User.create!(name: "Second Admin", email_address: "admin2@example.com", password: "password123", role: :admin)

    assert_enqueued_emails 2 do
      assert_difference -> { Notification.where(kind: "new_flag").count }, 2 do
        Flag.create!(reporter: @alice, flaggable: @bob_comment, reason: "offensive")
      end
    end
    assert users(:admin).notifications.exists?(kind: "new_flag", actor: @alice)
  end

  test "dismissing resolves every open report about the thing" do
    carol = User.create!(name: "Carol", email_address: "carol@example.com", password: "password123")
    Flag.create!(reporter: @alice, flaggable: @bob_comment, reason: "spam")
    Flag.create!(reporter: carol, flaggable: @bob_comment, reason: "offensive")

    assert_equal 1, Flag.reported_items_count # two reports, one comment
    assert_equal 2, Flag.dismiss_all_for(@bob_comment, by: users(:admin))
    assert_equal 0, Flag.reported_items_count
    assert_equal users(:admin), Flag.last.resolved_by
  end

  test "deleting the reported thing deletes its reports and their notifications" do
    Flag.create!(reporter: @alice, flaggable: @bob_comment, reason: "spam")
    assert_difference [ "Flag.count", -> { Notification.where(kind: "new_flag").count } ], -1 do
      @bob_comment.destroy!
    end
  end
end
