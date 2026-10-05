# Members list and profile pages.
class UsersController < ApplicationController
  before_action :set_user, only: %i[ show followers following ]

  def index
    @pagination = Pagination.new(User.order(:name), page: params[:page], per_page: 30)
    @users = @pagination.records
  end

  # /users/:id?q=hobbit searches this person's books only.
  def show
    @query = params[:q].to_s.squish
    books = @user.books.with_attached_cover.includes(:user).order(:title)
    books = books.search(@query) if @query.present?
    @pagination = Pagination.new(books, page: params[:page], per_page: 24)
    @books = @pagination.records
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
