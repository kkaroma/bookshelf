# Runs every 15 minutes while the site is awake (config/recurring.yml) and
# makes a backup when the last one is a day old. `force: true` (the admin's
# "Back up now" button) makes one regardless.
class DatabaseBackupJob < ApplicationJob
  queue_as :default
  # Never two backups at once (e.g. the schedule and the button together).
  limits_concurrency to: 1, key: "database_backup", duration: 30.minutes

  def perform(force: false)
    DatabaseBackup.create! if force || DatabaseBackup.due?
  end
end
