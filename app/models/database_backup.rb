require "open3"

# Daily copies of the whole database, saved as files next to the book covers
# (Tigris in production). Neon's free plan can only rewind the last few
# hours; these let you go back up to KEEP days.
#
# Each backup is a pg_dump file ("custom" format) stored as an Active Storage
# blob with a readable key, e.g. backups/bookshelf-2026-10-09-0315.dump, so
# the files can be found in the bucket even if the database itself is lost.
#
# The site sleeps when nobody uses it, so instead of "at 3am" the check runs
# every 15 minutes while it's awake (config/recurring.yml) and makes a backup
# when the last one is a day old. While the site sleeps nothing changes, so
# nothing is missed.
class DatabaseBackup
  KEY_PREFIX = "backups/"
  KEEP = 14
  EVERY = 1.day

  class Failed < StandardError; end

  # Saved backups, newest first (ActiveStorage::Blob records).
  def self.all
    ActiveStorage::Blob.where("key LIKE ?", "#{KEY_PREFIX}%").order(created_at: :desc)
  end

  def self.latest = all.first

  def self.due?(now: Time.current)
    latest.nil? || latest.created_at <= now - EVERY + 1.hour # an hour's slack so it doesn't creep later each day
  end

  # Dumps the database, uploads the file and removes backups beyond KEEP.
  def self.create!(now: Time.current)
    Tempfile.create([ "bookshelf-backup", ".dump" ], binmode: true) do |file|
      dump_to(file.path)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(file.path, "rb"),
        filename: "bookshelf-#{now.utc.strftime("%Y-%m-%d-%H%M")}.dump",
        key: "#{KEY_PREFIX}bookshelf-#{now.utc.strftime("%Y-%m-%d-%H%M%S")}.dump",
        content_type: "application/octet-stream",
        identify: false
      )
      prune!
      blob
    end
  end

  def self.prune!
    all.offset(KEEP).each(&:purge)
  end

  # pg_dump reads the connection details from PG* environment variables, so
  # the password never appears in the command line. Background-job and cache
  # rows are skipped: they're temporary and can be large.
  def self.dump_to(path)
    output, status = Open3.capture2e(pg_env, "pg_dump", "--format=custom", "--no-owner", "--no-acl",
                                     "--exclude-table-data=solid_*", "--file", path)
    raise Failed, "pg_dump failed: #{output.strip}" unless status.success?
  end

  def self.pg_env(config = ActiveRecord::Base.connection_db_config.configuration_hash)
    {
      "PGHOST"        => config[:host],
      "PGPORT"        => config[:port]&.to_s,
      "PGUSER"        => config[:username],
      "PGPASSWORD"    => config[:password],
      "PGDATABASE"    => config[:database],
      "PGSSLMODE"     => config[:sslmode],
      "PGGSSENCMODE"  => config[:gssencmode]
    }.compact
  end
end
