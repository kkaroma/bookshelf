# Block (POST) or unblock (DELETE) private messages from a member.
# The blocked member isn't told; they just can't send you messages.
class Users::BlocksController < ApplicationController
  before_action :set_user

  def create
    if @user == Current.user
      redirect_back_or_to @user, alert: "You can't block yourself."
    else
      Current.user.blocks.find_or_create_by!(blocked: @user)
      redirect_back_or_to @user, notice: "You've blocked #{@user.name}. They can't send you messages."
    end
  end

  def destroy
    Current.user.blocks.where(blocked: @user).destroy_all
    redirect_back_or_to @user, notice: "You've unblocked #{@user.name}."
  end

  private
    def set_user
      @user = User.find(params.expect(:user_id))
    end
end
