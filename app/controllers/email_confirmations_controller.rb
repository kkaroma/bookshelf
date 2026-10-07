# GET  /email_confirmation?token=...  the link in the email; works signed in or out.
# POST /email_confirmation            emails the link again to the signed-in member.
class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 3, within: 10.minutes, only: :create,
             with: -> { redirect_back_or_to root_path, alert: "We've sent a few emails already — please check your inbox (and spam folder), or try again later." }

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token].to_s)

    if user
      user.confirm_email!
      redirect_to (authenticated? ? root_path : new_session_path),
                  notice: "Thanks, your email address is confirmed."
    else
      redirect_to root_path, alert: "That confirmation link is invalid or has expired. Sign in and ask for a new one."
    end
  end

  def create
    if Current.user.email_confirmed?
      redirect_back_or_to root_path, notice: "Your email address is already confirmed."
    else
      Current.user.send_email_confirmation
      redirect_back_or_to root_path, notice: "We've emailed a new confirmation link to #{Current.user.email_address}."
    end
  end
end
