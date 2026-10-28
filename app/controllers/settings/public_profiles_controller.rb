# The answer to Home's one-time "Make your profile public?" question.
# PATCH /settings/public_profile with public_profile=1 or 0.
class Settings::PublicProfilesController < Settings::BaseController
  def update
    public = params[:public_profile] == "1"
    @user.update!(public_profile: public, public_profile_asked_at: Time.current)

    notice = public ? "Your profile is public. Use “Share” on your books to send people your reviews." :
                      "Your profile stays private. You can change this any time in Settings → Profile."
    redirect_to root_path, notice: notice
  end
end
