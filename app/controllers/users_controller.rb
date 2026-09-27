# Members list and profile pages.
class UsersController < ApplicationController
  before_action :set_user, only: %i[ show followers following ]

  def index
    @users = User.order(:name)
  end

  def show
    @books = @user.books.with_attached_cover.includes(:user).order(:title)
  end

  def followers
    @people = @user.followers.order(:name)
    render :people, locals: { title: "Followers", empty: "No one follows #{@user.name} yet." }
  end

  def following
    @people = @user.following.order(:name)
    render :people, locals: { title: "Following", empty: "#{@user.name} isn't following anyone yet." }
  end

  private
    def set_user
      @user = User.find(params.expect(:id))
    end
end
