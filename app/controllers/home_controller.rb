# The front page: a welcome page for visitors, a Home dashboard for members.
class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    if authenticated?
      dashboard
    else
      landing
    end
  end

  private
    # Visitors: explain the site and show recent covers (titles and covers only).
    def landing
      @recent_books = Book.with_attached_cover.order(created_at: :desc).limit(6)
      @book_count = Book.count
      @reader_count = User.count
      render :landing
    end

    def dashboard
      user = Current.user
      @getting_started = GettingStarted.new(user)
      @waiting_requests_count = user.received_exchange_requests.pending.count

      @followed_books = Book.where(user_id: user.active_follows.select(:followed_id))
                            .with_attached_cover.includes(:user).order(created_at: :desc).limit(6)
      @exchange_books = Book.for_exchange.where.not(user: user)
                            .with_attached_cover.includes(:user).order(updated_at: :desc).limit(6)
      @my_books = user.books.with_attached_cover.includes(:user).order(created_at: :desc).limit(6)
      render :dashboard
    end
end
