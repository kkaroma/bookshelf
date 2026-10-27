require "test_helper"

class BlockTest < ActiveSupport::TestCase
  test "blocking and checking" do
    alice, bob = users(:one), users(:two)
    alice.blocks.create!(blocked: bob)

    assert alice.blocking?(bob)
    assert_not bob.blocking?(alice)
  end

  test "once per pair, and never yourself" do
    alice = users(:one)
    alice.blocks.create!(blocked: users(:two))
    assert_not alice.blocks.build(blocked: users(:two)).valid?
    assert_not alice.blocks.build(blocked: alice).valid?
  end
end
