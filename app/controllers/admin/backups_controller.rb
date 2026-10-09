# /admin/backups - the daily database backups: see them, make one now, and
# download one (e.g. to restore the site after a mistake).
class Admin::BackupsController < Admin::BaseController
  # send_blob_stream: sends a stored file through this (admin-only) page.
  include ActiveStorage::Streaming

  def index
    @backups = DatabaseBackup.all.to_a
  end

  def create
    DatabaseBackupJob.perform_later(force: true)
    redirect_to admin_backups_path, notice: "Backup started. It takes under a minute — refresh this page to see it."
  end

  # The file comes through this page rather than a link to the storage
  # bucket, so it can only ever be downloaded by a signed-in admin.
  def show
    send_blob_stream DatabaseBackup.all.find(params.expect(:id)), disposition: :attachment
  end
end
