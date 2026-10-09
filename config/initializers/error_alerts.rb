# Email the admins about unexpected errors on the live site (see ErrorAlert).
# Off in development and tests, where errors show on screen.
Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorAlert.new) if Rails.env.production?
end
