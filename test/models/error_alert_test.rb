require "test_helper"

class ErrorAlertTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @alert = ErrorAlert.new(cache: ActiveSupport::Cache::MemoryStore.new)
  end

  def boom(message = "undefined method 'title' for nil")
    raise NoMethodError, message
  rescue => error
    error
  end

  def report(error = boom, handled: false, severity: :error, context: {})
    @alert.report(error, handled: handled, severity: severity, context: context, source: "application.action_dispatch")
  end

  test "an unexpected error emails the admins with the page and member" do
    assert_enqueued_email_with ErrorMailer, :alert,
        args: ->(args) { args.first[:to] == [ "admin@example.com" ] && args.first[:error_class] == "NoMethodError" &&
                         args.first[:url] == "https://bookshelf.co.tz/books/1" && args.first[:user_id] == 7 } do
      report(context: { url: "https://bookshelf.co.tz/books/1", user_id: 7 })
    end
  end

  test "ERROR_EMAIL gets alerts too" do
    ENV["ERROR_EMAIL"] = "me@example.com"
    assert_equal [ "admin@example.com", "me@example.com" ], ErrorAlert.recipients
  ensure
    ENV.delete("ERROR_EMAIL")
  end

  test "suspended admins don't get alerts" do
    users(:admin).update_columns(suspended_at: Time.current)
    assert_empty ErrorAlert.recipients
    assert_no_enqueued_emails { report }
  end

  test "the same error is emailed at most once an hour" do
    error = boom
    assert_enqueued_emails(1) { 3.times { report(error) } }

    travel 61.minutes
    assert_enqueued_emails(1) { report(error) }
  end

  test "a different error is emailed straight away" do
    assert_enqueued_emails(2) do
      report(boom)
      report(ArgumentError.new("something else"))
    end
  end

  test "problems the code handled itself are not emailed" do
    assert_no_enqueued_emails { report(handled: true, severity: :warning) }
  end

  test "a problem sending the alert never raises" do
    swap_method(ErrorMailer, :alert, proc { raise "mail is broken" }) do
      assert_nothing_raised { report }
    end
  end

  test "the email shows what broke and where" do
    email = ErrorMailer.alert(to: [ "admin@example.com" ], error_class: "NoMethodError",
                              message: "undefined method 'title' for nil", backtrace: [ "app/views/books/show.html.erb:3" ],
                              source: "application.action_dispatch", url: "https://bookshelf.co.tz/books/1", user_id: users(:one).id)

    assert_equal "Bookshelf error: NoMethodError", email.subject
    assert_match "undefined method 'title' for nil", email.text_part.body.to_s
    assert_match "app/views/books/show.html.erb:3", email.text_part.body.to_s
    assert_match "https://bookshelf.co.tz/books/1", email.html_part.body.to_s
  end
end
