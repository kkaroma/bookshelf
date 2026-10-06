# The notification bell's page, plus opening and clearing notifications.
class NotificationsController < ApplicationController
  helper NotificationsHelper

  def index
    @pagination = Pagination.new(Current.user.notifications.includes(:actor, :notifiable), page: params[:page], per_page: 30)
    @notifications = @pagination.records
  end

  # Opening a notification marks it read and takes you to what it's about.
  def show
    notification = Current.user.notifications.find(params.expect(:id))
    notification.mark_read!
    redirect_to helpers.notification_target_path(notification)
  end

  def mark_all_read
    Current.user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "All notifications marked as read.", status: :see_other
  end
end
