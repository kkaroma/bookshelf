# See these emails in the browser while developing:
# http://localhost:3000/rails/mailers/notifications_mailer
class NotificationsMailerPreview < ActionMailer::Preview
  def exchange_request_received
    NotificationsMailer.exchange_request_received(ExchangeRequest.first || sample_request)
  end

  def exchange_request_accepted
    request = ExchangeRequest.first || sample_request
    request.status = :accepted
    NotificationsMailer.exchange_request_answered(request)
  end

  def exchange_request_declined
    request = ExchangeRequest.first || sample_request
    request.status = :declined
    NotificationsMailer.exchange_request_answered(request)
  end

  def new_comment
    comment = Comment.first
    NotificationsMailer.new_comment(comment, comment.book.user)
  end

  def new_follower
    NotificationsMailer.new_follower(Follow.first)
  end

  def new_flag
    comment = Comment.first
    reporter = User.where.not(id: comment.user_id).first
    flag = Flag.new(flaggable: comment, reporter: reporter, reason: "offensive", note: "Not very kind.")
    NotificationsMailer.new_flag(flag, User.admin.first)
  end

  private
    # An unsaved example, for when the database has no requests yet.
    def sample_request
      book = Book.first
      ExchangeRequest.new(book: book, requester: User.where.not(id: book.user_id).first,
                          message: "I'd love to read this one!", status: :pending)
    end
end
