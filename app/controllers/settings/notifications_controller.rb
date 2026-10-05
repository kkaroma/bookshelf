# Settings → Notifications: choose which emails you get.
class Settings::NotificationsController < Settings::BaseController
  def edit
  end

  def update
    @user.update!(params.expect(user: [ :notify_exchange_requests, :notify_comments, :notify_followers ]))
    redirect_to edit_settings_notifications_path, notice: "Your email preferences were saved."
  end
end
