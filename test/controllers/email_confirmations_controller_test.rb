require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @alice = users(:one)
    @alice.update_columns(email_confirmed_at: nil)
  end

  test "the link in the email confirms the address, even when signed out" do
    get email_confirmation_url(token: @alice.generate_token_for(:email_confirmation))

    assert @alice.reload.email_confirmed?
    assert_redirected_to new_session_url
    assert_equal "Thanks, your email address is confirmed.", flash[:notice]
  end

  test "signed in, the link goes back to Home" do
    sign_in_as @alice
    get email_confirmation_url(token: @alice.generate_token_for(:email_confirmation))
    assert_redirected_to root_url
  end

  test "a bad or expired link confirms nothing" do
    get email_confirmation_url(token: "nonsense")
    assert_not @alice.reload.email_confirmed?
    assert_match(/invalid or has expired/, flash[:alert])
  end

  test "unconfirmed members see a banner and can ask for the email again" do
    sign_in_as @alice
    get root_url
    assert_select ".confirm-banner", /We sent a link to one@example.com/

    assert_enqueued_email_with AccountMailer, :email_confirmation, args: [ @alice ] do
      post email_confirmation_url
    end
    assert_match(/We've emailed a new confirmation link/, flash[:notice])
  end

  test "confirmed members see no banner" do
    @alice.confirm_email!
    sign_in_as @alice
    get root_url
    assert_select ".confirm-banner", 0
  end

  test "unconfirmed members can't comment, request swaps or send messages" do
    sign_in_as @alice

    assert_no_difference("Comment.count") do
      post book_comments_url(books(:dune)), params: { comment: { body: "Buy cheap watches!" } }
    end
    assert_match(/confirm your email/, flash[:alert])

    get new_book_exchange_request_url(books(:dune))
    assert_redirected_to root_url

    assert_no_difference("ExchangeRequest.count") do
      post book_exchange_requests_url(books(:dune)), params: { exchange_request: { message: "hi" } }
    end
  end
end
