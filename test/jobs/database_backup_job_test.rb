require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
  test "makes a backup only when one is due" do
    calls = 0
    swap_method(DatabaseBackup, :create!, proc { calls += 1 }) do
      swap_method(DatabaseBackup, :due?, false) { DatabaseBackupJob.perform_now }
      assert_equal 0, calls

      swap_method(DatabaseBackup, :due?, true) { DatabaseBackupJob.perform_now }
      assert_equal 1, calls
    end
  end

  test "force makes one regardless" do
    calls = 0
    swap_method(DatabaseBackup, :create!, proc { calls += 1 }) do
      swap_method(DatabaseBackup, :due?, false) { DatabaseBackupJob.perform_now(force: true) }
    end
    assert_equal 1, calls
  end

  test "is scheduled every 15 minutes in production" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "database_backup")
    assert_equal "DatabaseBackupJob", schedule["class"]
    assert_equal "every 15 minutes", schedule["schedule"]
  end
end
