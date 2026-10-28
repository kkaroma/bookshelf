# Members list and profile pages.
class UsersController < ApplicationController
  before_action :set_user, only: %i[ show followers following ]

  # /users?q=dar searches members by name or town.
  def index
    @query = params[:q].to_s.squish
    @pagination = Pagination.new(User.active.search(@query).order(:name), page: params[:page], per_page: 30)
    @users = @pagination.records
  end

  # /users/:id?q=hobbit searches this person's books only.
  def show
    @filters = BookFilters.new(params, allow_status: true)
    books = @filters.apply(@user.books.on_shelf.with_attached_cover.includes(:user, :loans))
    @pagination = Pagination.new(books, page: params[:page], per_page: 24)
    @currently_reading = @user.books.on_shelf.reading.order(started_on: :desc).limit(3)
    @past_books = @user.past_books.with_attached_cover.includes(:user, :given_to, :successor)
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
