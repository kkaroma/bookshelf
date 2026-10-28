require "test_helper"

class PublicProfileSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    sign_in_as @alice
  end

  test "Home asks once; either answer stops the question" do
    get root_url
    assert_select ".public-question h2", "Share your reviews with everyone?"

    patch settings_public_profile_url, params: { public_profile: "1" }
    assert @alice.reload.public_profile?
    assert_redirected_to root_url
    follow_redirect!
    assert_select ".public-question", 0

    @alice.update!(public_profile_asked_at: nil)
    patch settings_public_profile_url, params: { public_profile: "0" }
    assert_not @alice.reload.public_profile?
    assert @alice.public_profile_asked_at.present?
  end

  test "the switch in Settings → Profile" do
    get edit_settings_profile_url
    assert_select "input[type=checkbox][name=?]", "user[public_profile]"

    patch settings_profile_url, params: { user: { name: @alice.name, email_address: @alice.email_address, public_profile: "1" } }
    assert @alice.reload.public_profile?
    assert @alice.public_profile_asked_at.present? # so Home doesn't ask again
  end

  test "owners see whether their pages are public, with Share" do
    get user_url(@alice)
    assert_select ".visibility-note", /Only members can see your profile/
    get book_url(books(:hobbit))
    assert_select ".visibility-note", /Make your profile public/

    @alice.update!(public_profile: true)
    get user_url(@alice)
    assert_select ".visibility-note a[href=?]", user_path(@alice, as: "visitor")
    get book_url(books(:hobbit))
    assert_select ".book-share .share"
  end

  test "see your profile as visitors do" do
    @alice.update!(public_profile: true)
    get user_url(@alice, as: "visitor")
    assert_select ".join-card" # the visitors' page
    assert_no_match @alice.email_address, response.body

    get user_url(users(:two), as: "visitor") # not for other people's profiles
    assert_select ".join-card", 0
  end
end
