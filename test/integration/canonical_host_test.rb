require "test_helper"

class CanonicalHostTest < ActionDispatch::IntegrationTest
  teardown { ENV.delete("CANONICAL_HOST") }

  test "with no CANONICAL_HOST set, every address works as normal" do
    host! "kkaroma-bookshelf.fly.dev"
    get root_path
    assert_response :success
  end

  test "other addresses redirect to the main one, keeping the page and search" do
    ENV["CANONICAL_HOST"] = "bookshelf.co.tz"

    host! "www.bookshelf.co.tz"
    get "/books?q=hobbit&page=2"
    assert_response :moved_permanently
    assert_redirected_to "https://bookshelf.co.tz/books?q=hobbit&page=2"

    host! "kkaroma-bookshelf.fly.dev"
    get "/"
    assert_redirected_to "https://bookshelf.co.tz/"
  end

  test "the main address itself is not redirected" do
    ENV["CANONICAL_HOST"] = "bookshelf.co.tz"
    host! "bookshelf.co.tz"
    get root_path
    assert_response :success
  end

  test "the health check is never redirected" do
    ENV["CANONICAL_HOST"] = "bookshelf.co.tz"
    host! "172.19.0.2" # Fly checks the machine by its internal address
    get "/up"
    assert_response :success
  end
end
