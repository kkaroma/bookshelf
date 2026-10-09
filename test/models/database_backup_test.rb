require "test_helper"

class DatabaseBackupTest < ActiveSupport::TestCase
  def fake_backup(at:, name: "bookshelf-#{at.to_i}.dump")
    travel_to(at) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("PGDMP fake"), filename: name,
                                             key: "#{DatabaseBackup::KEY_PREFIX}#{name}", identify: false)
    end
  end

  test "lists only backups, newest first" do
    old = fake_backup(at: 2.days.ago)
    new = fake_backup(at: 1.hour.ago)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("not a backup"), filename: "cover.jpg")

    assert_equal [ new, old ], DatabaseBackup.all.to_a
    assert_equal new, DatabaseBackup.latest
  end

  test "a backup is due when there is none, or the last is about a day old" do
    assert DatabaseBackup.due?

    fake_backup(at: 3.hours.ago)
    assert_not DatabaseBackup.due?

    travel 21.hours
    assert DatabaseBackup.due? # 24h minus an hour of slack
  end

  test "keeps only the newest #{DatabaseBackup::KEEP}" do
    16.times { |i| fake_backup(at: (16 - i).days.ago) }
    DatabaseBackup.prune!

    assert_equal DatabaseBackup::KEEP, DatabaseBackup.all.count
    assert DatabaseBackup.all.last.created_at > 15.days.ago
  end

  test "connection details go to pg_dump as environment variables, not command-line arguments" do
    env = DatabaseBackup.pg_env({ host: "ep-cool.eu-central-1.aws.neon.tech", port: 5432, username: "bookshelf",
                                  password: "s3cret", database: "neondb", sslmode: "require" })

    assert_equal({ "PGHOST" => "ep-cool.eu-central-1.aws.neon.tech", "PGPORT" => "5432", "PGUSER" => "bookshelf",
                   "PGPASSWORD" => "s3cret", "PGDATABASE" => "neondb", "PGSSLMODE" => "require" }, env)
  end

  test "a failed pg_dump raises with its message" do
    swap_method(DatabaseBackup, :pg_env, { "PGDATABASE" => "no_such_database_here", "PGGSSENCMODE" => "disable" }) do
      error = assert_raises(DatabaseBackup::Failed) { DatabaseBackup.create! }
      assert_match(/no_such_database_here/, error.message)
    end
    assert_equal 0, DatabaseBackup.all.count
  end

  test "makes a real backup that pg_restore can read" do
    skip_unless_pg_dump_matches_server

    blob = DatabaseBackup.create!(now: Time.utc(2026, 10, 9, 3, 15))

    assert_equal "bookshelf-2026-10-09-0315.dump", blob.filename.to_s
    assert blob.key.start_with?("backups/bookshelf-2026-10-09-0315")
    path = ActiveStorage::Blob.service.path_for(blob.key)
    assert_equal "PGDMP", File.binread(path, 5)

    contents, status = Open3.capture2e("pg_restore", "--list", path)
    assert status.success?, contents
    assert_match(/TABLE DATA public books/, contents)
    assert_no_match(/TABLE DATA public solid_queue_jobs/, contents) # temporary data left out
  end

  private
    # pg_dump refuses to dump a newer server (e.g. CI's runner tools vs its database).
    def skip_unless_pg_dump_matches_server
      tool = `pg_dump --version`[/\d+/].to_i
      server = ActiveRecord::Base.connection.select_value("SHOW server_version")[/\d+/].to_i
      skip "pg_dump #{tool} can't dump PostgreSQL #{server}" if tool < server
    rescue Errno::ENOENT
      skip "pg_dump isn't installed"
    end
end
