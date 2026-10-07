ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/open_library_test_helper"

# Tests fill in the sign-up form instantly; the "too quick, must be a robot"
# check has its own test that switches it back on.
RegistrationsController.minimum_fill_time = 0.seconds

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
