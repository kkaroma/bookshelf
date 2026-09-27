# Follow (create) or unfollow (destroy) a member: /users/:user_id/follow
class Users::FollowsController < ApplicationController
  before_action :set_user

  def create
    Current.user.follow(@user)
    redirect_back_or_to @user, notice: "You're now following #{@user.name}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_back_or_to @user, alert: error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    # Already following (e.g. a double click) - nothing to do.
    redirect_back_or_to @user
  end

  def destroy
    Current.user.unfollow(@user)
    redirect_back_or_to @user, notice: "You've unfollowed #{@user.name}.", status: :see_other
  end

  private
    def set_user
      @user = User.find(params.expect(:user_id))
    end
end
