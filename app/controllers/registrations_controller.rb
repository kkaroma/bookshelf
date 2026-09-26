class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_authenticated
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Bookshelf, #{@user.name}!"
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
    end
end
