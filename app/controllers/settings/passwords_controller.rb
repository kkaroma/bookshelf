# Settings → Password: change your password (not the "forgot password" flow,
# which is PasswordsController).
class Settings::PasswordsController < Settings::BaseController
  def edit
  end

  def update
    new_password = params.expect(user: [ :password, :password_confirmation ])

    if !@user.authenticate(params[:current_password].to_s)
      @user.errors.add(:base, "Your current password is incorrect")
    elsif new_password[:password].blank?
      @user.errors.add(:password, "can't be blank")
    elsif @user.update(new_password)
      # Sign out everywhere else, in case someone else knew the old password.
      @user.sessions.where.not(id: Current.session.id).destroy_all
      return redirect_to edit_settings_password_path,
                         notice: "Password changed. You've been signed out on your other devices."
    end

    render :edit, status: :unprocessable_content
  end
end
