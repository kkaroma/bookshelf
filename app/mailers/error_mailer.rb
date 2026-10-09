# "Something broke on Bookshelf" emails to the admins (see ErrorAlert).
class ErrorMailer < ApplicationMailer
  def alert(to:, error_class:, message:, backtrace:, source:, url:, user_id:)
    @error_class = error_class
    @message = message
    @backtrace = backtrace
    @source = source
    @url = url
    @user_id = user_id
    mail to: to, subject: "Bookshelf error: #{error_class}"
  end
end
