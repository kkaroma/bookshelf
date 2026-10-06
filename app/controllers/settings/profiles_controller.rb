# Settings → Profile: change your name and email address.
class Settings::ProfilesController < Settings::BaseController
  def edit
  end

  def update
    @user.assign_attributes(params.expect(user: [ :name, :email_address, :city ]))

    # Whoever controls the email address can reset the password, so changing
    # it needs the current password.
    if @user.email_address_changed? && !@user.authenticate(params[:current_password].to_s)
      @user.errors.add(:base, "Enter your current password to change your email address")
      render :edit, status: :unprocessable_content
    elsif @user.save
      redirect_to edit_settings_profile_path, notice: "Your profile was saved."
    else
      render :edit, status: :unprocessable_content
    end
  end
end
