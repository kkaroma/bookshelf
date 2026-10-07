# Sending a message in an exchange request's conversation.
class ExchangeRequests::MessagesController < ApplicationController
  before_action :set_exchange_request
  before_action :require_confirmed_email

  def create
    @message = @exchange_request.messages.build(params.expect(message: [ :body ]).merge(sender: Current.user))

    respond_to do |format|
      if @exchange_request.open_for_messages? && @message.save
        format.turbo_stream # create.turbo_stream.erb: add the message, clear the box
        format.html { redirect_to exchange_request_path(@exchange_request, anchor: helpers.dom_id(@message)) }
      else
        @message.errors.add(:base, "This request is closed, so no more messages can be sent.") unless @exchange_request.open_for_messages?
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_message", partial: "exchange_requests/messages/form", locals: { exchange_request: @exchange_request, message: @message }), status: :unprocessable_content }
        format.html { redirect_to exchange_request_path(@exchange_request), alert: @message.errors.full_messages.to_sentence }
      end
    end
  end

  private
    def set_exchange_request
      @exchange_request = ExchangeRequest.find(params.expect(:exchange_request_id))
      head :not_found unless @exchange_request.participant?(Current.user)
    end
end
