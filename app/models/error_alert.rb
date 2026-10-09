# Emails the admins when something breaks on the live site, so you hear about
# it before a member does. No outside service needed.
#
# Rails reports every unexpected error (a crashed page, a failed background
# job) to Rails.error; config/initializers/error_alerts.rb subscribes this
# class to it in production. "Page not found" and similar aren't reported.
#
# The same error is emailed at most once an hour, so a broken page that many
# people visit doesn't flood your inbox.
class ErrorAlert
  QUIET_FOR = 1.hour

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  # Called by Rails.error for every reported error.
  def report(error, handled:, severity:, context:, source: nil)
    return if handled && severity != :error # warnings and errors the code dealt with itself
    return unless first_time_this_hour?(error)

    recipients = self.class.recipients
    return if recipients.empty?

    ErrorMailer.alert(
      to: recipients,
      error_class: error.class.name,
      message: error.message.to_s.truncate(1000),
      backtrace: Rails.backtrace_cleaner.clean(Array(error.backtrace)).first(15),
      source: source,
      url: context[:url],
      user_id: context[:user_id]
    ).deliver_later
  rescue StandardError => alert_error
    # Never let a problem sending the alert cause another error.
    Rails.logger.error("ErrorAlert couldn't send an alert: #{alert_error.class}: #{alert_error.message}")
  end

  # Every admin, plus ERROR_EMAIL if that's set.
  def self.recipients
    (User.admin.active.pluck(:email_address) + [ ENV["ERROR_EMAIL"] ]).compact_blank.uniq
  end

  private
    # Same kind of error from the same line of code = the same problem.
    def first_time_this_hour?(error)
      where = Rails.backtrace_cleaner.clean(Array(error.backtrace)).first
      key = "error-alert/#{Digest::SHA256.hexdigest("#{error.class}|#{where}")}"
      @cache.write(key, true, expires_in: QUIET_FOR, unless_exist: true)
    end
end
