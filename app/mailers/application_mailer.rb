class ApplicationMailer < ActionMailer::Base
  # The sender address. In production set the MAIL_FROM secret to an address
  # your email service has verified, e.g. "Bookshelf <bookshelf@example.com>".
  default from: -> { ENV.fetch("MAIL_FROM", "Bookshelf <no-reply@bookshelf.test>") }
  layout "mailer"
end
