# /admin/users - admins manage members: make or remove admins, suspend and
# reinstate members, and confirm an email address by hand.
class Admin::UsersController < Admin::BaseController
  SHOW = %w[ all admins suspended unconfirmed ].freeze

  before_action :set_user, except: :index

  def index
    @query = params[:q].to_s.squish
    @show = SHOW.include?(params[:show]) ? params[:show] : "all"

    users = User.order(:name)
    users = users.where("users.name ILIKE :q OR users.email_address ILIKE :q",
                        q: "%#{User.sanitize_sql_like(@query)}%") if @query.present?
    users = case @show
    when "admins"      then users.admin
    when "suspended"   then users.where.not(suspended_at: nil)
    when "unconfirmed" then users.where(email_confirmed_at: nil)
    else users
    end

    @pagination = Pagination.new(users, page: params[:page], per_page: 30)
    @users = @pagination.records
  end

  def promote
    if @user.suspended?
      back alert: "Reinstate #{@user.name} before making them an admin."
    else
      @user.admin!
      back notice: "#{@user.name} is now an admin."
    end
  end

  def demote
    if @user.last_admin?
      back alert: "#{@user.name} is the only admin. Make someone else an admin first."
    else
      @user.member!
      back notice: "#{@user.name} is no longer an admin."
    end
  end

  def suspend
    if @user == Current.user
      back alert: "You can't suspend yourself."
    elsif @user.admin?
      back alert: "#{@user.name} is an admin. Remove their admin role first."
    else
      @user.suspend!
      back notice: "#{@user.name} is suspended and has been signed out. Their books are off the Exchange shelf."
    end
  end

  def reinstate
    @user.reinstate!
    back notice: "#{@user.name} can sign in again."
  end

  def confirm_email
    @user.confirm_email!
    back notice: "#{@user.name}'s email address is now confirmed."
  end

  private
    def set_user
      @user = User.find(params.expect(:id))
    end

    # Back to the list, keeping its search, filter and page.
    def back(**flash)
      redirect_back_or_to admin_users_path, **flash
    end
end
