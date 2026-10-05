# Settings → Delete account.
class Settings::AccountsController < Settings::BaseController
  def show
  end

  def destroy
    if @user.last_admin?
      redirect_to settings_account_path, alert: "You're the only admin, so your account can't be deleted. Make someone else an admin first."
    elsif !@user.authenticate(params[:password].to_s)
      @user.errors.add(:base, "Your password is incorrect")
      render :show, status: :unprocessable_content
    else
      # Also deletes their books, comments, ratings, follows, requests and sessions
      # (see the dependent: :destroy associations on User).
      @user.destroy!
      cookies.delete(:session_id)
      redirect_to root_path, notice: "Your account has been deleted. Sorry to see you go!", status: :see_other
    end
  end
end
