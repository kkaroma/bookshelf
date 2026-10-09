require "test_helper"

class Admin::BackupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as users(:admin) }

  def make_backup
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("PGDMP fake"), filename: "bookshelf-2026-10-09-0315.dump",
                                           key: "backups/bookshelf-test.dump", identify: false)
  end

  test "an empty list explains when the first backup happens" do
    get admin_backups_url
    assert_response :success
    assert_select ".tabs a.active", "Backups"
    assert_select ".empty-state h2", "No backups yet"
  end

  test "lists backups with download links and restore help" do
    backup = make_backup
    get admin_backups_url

    assert_select ".backup-status", /Last backup/
    assert_select ".backup-list li", 1
    assert_select ".backup-list a[href=?]", admin_backup_path(backup), "Download"
    assert_select ".backup-help summary", "How to restore a backup"
  end

  test "Back up now queues a backup" do
    assert_enqueued_with(job: DatabaseBackupJob, args: [ { force: true } ]) do
      post admin_backups_url
    end
    assert_redirected_to admin_backups_url
  end

  test "download sends the file itself" do
    backup = make_backup
    get admin_backup_url(backup)
    assert_response :success
    assert_equal "PGDMP fake", response.body
    assert_match(/attachment; filename="bookshelf-2026-10-09-0315.dump"/, response.headers["Content-Disposition"])
  end

  test "only backups can be downloaded here" do
    cover = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "cover.jpg")
    get admin_backup_url(cover)
    assert_response :not_found
  end

  test "members get page not found" do
    backup = make_backup
    sign_out
    sign_in_as users(:one)

    get admin_backups_url
    assert_response :not_found
    get admin_backup_url(backup)
    assert_response :not_found
    assert_no_enqueued_jobs(only: DatabaseBackupJob) { post admin_backups_url }
  end
end
