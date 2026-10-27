# Private messages: the inbox (/conversations) and one conversation.
# Only the two members in a conversation can open it - for anyone else,
# admins included, it doesn't exist.
class ConversationsController < ApplicationController
  def index
    conversations = Current.user.conversations.with_messages
                           .includes(:user_one, :user_two).order(last_message_at: :desc)
    @pagination = Pagination.new(conversations, page: params[:page], per_page: 30)
    @conversations = @pagination.records.to_a

    ids = @conversations.map(&:id)
    @unread_counts = DirectMessage.unread_for(Current.user).where(conversation_id: ids).group(:conversation_id).count
    # The newest message of each conversation, for the preview line.
    @last_messages = DirectMessage.where(conversation_id: ids)
                                  .select("DISTINCT ON (conversation_id) direct_messages.*")
                                  .order(:conversation_id, created_at: :desc, id: :desc)
                                  .index_by(&:conversation_id)
  end

  def show
    @conversation = Current.user.conversations.find(params.expect(:id))
    @other = @conversation.other_participant(Current.user)
    @messages = @conversation.messages.includes(:sender)
    @conversation.mark_read_for!(Current.user)
  end
end
