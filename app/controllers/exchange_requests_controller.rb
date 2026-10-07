class ExchangeRequestsController < ApplicationController
  before_action :set_book, only: %i[ new create ]
  before_action :require_confirmed_email, only: %i[ new create ]
  before_action :require_requestable_book, only: %i[ new create ]
  before_action :set_exchange_request, only: %i[ show accept decline cancel complete ]
  before_action :require_participant, only: %i[ show complete ]
  before_action :require_book_owner, only: %i[ accept decline ]
  before_action :require_requester, only: :cancel

  # /exchange_requests (received) and /exchange_requests?box=sent
  def index
    @box = params[:box] == "sent" ? "sent" : "received"
    requests = @box == "sent" ? ExchangeRequest.sent_by(Current.user) : ExchangeRequest.received_by(Current.user)
    @exchange_requests = requests.includes(:requester, :owner, :offered_book, :messages, book: :user).newest_first
  end

  # One request, with its conversation. Opening it marks its message
  # notifications as read.
  def show
    @messages = @exchange_request.messages.includes(:sender)
    Current.user.notifications.unread
           .where(kind: "new_message", notifiable_type: "Message", notifiable_id: @exchange_request.messages.select(:id))
           .update_all(read_at: Time.current)
  end

  def new
    @exchange_request = @book.exchange_requests.build
  end

  def create
    @exchange_request = @book.exchange_requests.build(exchange_request_params.merge(requester: Current.user))

    if @exchange_request.save
      redirect_to exchange_requests_path(box: "sent"),
                  notice: "Request sent! We'll let #{@book.user.name} know you'd like “#{@book.title}”."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to exchange_requests_path(box: "sent"), alert: "You've already asked for this book."
  end

  def accept
    @exchange_request.accept!
    # Back to wherever it was answered from (the list, or the request's own page).
    redirect_back_or_to exchange_requests_path,
                notice: "You accepted #{@exchange_request.requester.name}'s request. Get in touch to arrange the swap!"
  end

  def decline
    @exchange_request.decline!
    redirect_back_or_to exchange_requests_path, notice: "Request declined."
  end

  # Either person: "we've swapped". The books change owners.
  def complete
    @exchange_request.complete!(by: Current.user)
    redirect_to exchange_request_path(@exchange_request),
                notice: "Swap done! “#{@exchange_request.book.title}” is now on #{@exchange_request.requester == Current.user ? "your" : "#{@exchange_request.requester.name}'s"} shelf."
  rescue ExchangeRequest::NotAccepted => error
    redirect_to exchange_request_path(@exchange_request), alert: error.message
  end

  def cancel
    @exchange_request.cancel!
    redirect_back_or_to exchange_requests_path(box: "sent"), notice: "Request cancelled."
  end

  # A request that's already been answered can't be answered again
  # (e.g. two browser tabs, or a double click).
  rescue_from ExchangeRequest::AlreadyAnswered do
    redirect_to exchange_requests_path, alert: "That request has already been answered."
  end

  private
    def set_book
      @book = Book.find(params.expect(:book_id))
    end

    def require_requestable_book
      unless @book.requestable_by?(Current.user)
        message = @book.owned_by?(Current.user) ? "You can't request your own book." : "This book isn't offered for exchange."
        redirect_to @book, alert: message
      end
    end

    def set_exchange_request
      @exchange_request = ExchangeRequest.find(params.expect(:id))
    end

    # Only the two people involved can see a request and its messages.
    def require_participant
      head :not_found unless @exchange_request.participant?(Current.user)
    end

    def require_book_owner
      unless @exchange_request.owner == Current.user
        redirect_to exchange_requests_path, alert: "Only the book's owner can answer this request."
      end
    end

    def require_requester
      unless @exchange_request.requester == Current.user
        redirect_to exchange_requests_path, alert: "Only the person who sent this request can cancel it."
      end
    end

    def exchange_request_params
      params.expect(exchange_request: [ :offered_book_id, :message ])
    end
end
