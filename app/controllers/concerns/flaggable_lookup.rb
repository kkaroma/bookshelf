# Finds the book, comment or private message a report is about. Which kind it
# is comes from the parameter's name (book_id, comment_id or message_id) -
# never from a class name typed into the address bar.
module FlaggableLookup
  extend ActiveSupport::Concern

  private
    def find_flaggable
      if params[:comment_id]
        Comment.find(params[:comment_id])
      elsif params[:message_id]
        DirectMessage.find(params[:message_id])
      else
        Book.find(params.expect(:book_id))
      end
    end
end
