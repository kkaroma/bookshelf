# Sending a private message: POST /conversations/:conversation_id/messages
class Conversations::MessagesController < ApplicationController
  before_action :require_confirmed_email
  before_action :set_conversation

  def create
    @message = @conversation.messages.build(params.expect(direct_message: [ :body ]).merge(sender: Current.user))

    respond_to do |format|
      if @message.save
        format.turbo_stream # create.turbo_stream.erb: add the message, clear the box
        format.html { redirect_to conversation_path(@conversation, anchor: helpers.dom_id(@message)) }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("new_direct_message", partial: "conversations/form",
                   locals: { conversation: @conversation, message: @message }), status: :unprocessable_content
        end
        format.html { redirect_to conversation_path(@conversation), alert: @message.errors.full_messages.to_sentence }
      end
    end
  end

  private
    def set_conversation
      @conversation = Current.user.conversations.find(params.expect(:conversation_id))
    end
end
