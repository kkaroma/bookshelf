# Preview at http://localhost:3000/rails/mailers/account_mailer
class AccountMailerPreview < ActionMailer::Preview
  def email_confirmation
    AccountMailer.email_confirmation(User.take)
  end
end
