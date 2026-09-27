# Creates the data the app needs to run. Safe to run many times
# (bin/rails db:seed): records that already exist are left alone.

# --- Admin account -----------------------------------------------------------
# Set ADMIN_EMAIL / ADMIN_PASSWORD to choose the credentials. Outside
# production there are development defaults; in production a password
# must be given, so a known default can never reach a live server.
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@bookshelf.test")
admin_password =
  if Rails.env.production?
    ENV.fetch("ADMIN_PASSWORD") { abort "Set ADMIN_PASSWORD to seed the admin account." }
  else
    ENV.fetch("ADMIN_PASSWORD", "bookshelf-admin")
  end

User.find_or_create_by!(email_address: admin_email) do |user|
  user.name = "Admin"
  user.password = admin_password
  user.role = :admin
end
