# The "Message" button on a profile: opens your conversation with that
# member, starting one if you've never talked.
class Users::ConversationsController < ApplicationController
  before_action :require_confirmed_email

  def create
    other = User.active.find(params.expect(:user_id))
    return redirect_to(other, alert: "You can't message yourself.") if other == Current.user

    conversation = Conversation.between(Current.user, other)
    redirect_to conversation_path(conversation, anchor: "new_direct_message")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to other, alert: error.record.errors.full_messages.to_sentence
  end
end
