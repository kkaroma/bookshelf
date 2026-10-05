# Emails telling members about things that happened to them on Bookshelf.
# Each is sent only if the recipient left that kind of email switched on
# (Settings → Notifications); the models decide that before calling these.
class NotificationsMailer < ApplicationMailer
  helper ApplicationHelper

  def exchange_request_received(exchange_request)
    @request = exchange_request
    @owner = exchange_request.owner
    mail to: @owner.email_address,
         subject: "#{@request.requester.name} wants to swap for “#{@request.book.title}”"
  end

  # Sent when a request is accepted or declined (including when it's declined
  # automatically because the book left the Exchange shelf).
  def exchange_request_answered(exchange_request)
    @request = exchange_request
    @requester = exchange_request.requester
    mail to: @requester.email_address,
         subject: "Your request for “#{@request.book.title}” was #{@request.status}"
  end

  def new_comment(comment, recipient)
    @comment = comment
    @recipient = recipient
    @reply_to_you = comment.reply? && comment.parent.user_id == recipient.id
    subject = if @reply_to_you
      "#{comment.user.name} replied to your comment on “#{comment.book.title}”"
    else
      "#{comment.user.name} commented on “#{comment.book.title}”"
    end
    mail to: recipient.email_address, subject: subject
  end

  def new_follower(follow)
    @follower = follow.follower
    @followed = follow.followed
    mail to: @followed.email_address, subject: "#{@follower.name} is now following you on Bookshelf"
  end
end
