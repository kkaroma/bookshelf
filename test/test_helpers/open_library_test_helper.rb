# Tests never talk to the real Open Library. By default any attempt fails
# loudly; a test that needs Open Library sets up fake answers instead:
#
#   fake_open_library "search.json" => open_library_json([ { "cover_i" => 1, "title" => "Dune" } ]),
#                     "covers.openlibrary.org" => open_library_image
module OpenLibraryTestHelper
  BLOCKED = ->(uri) { raise "Tests must not call the real Open Library (#{uri})" }

  def fake_open_library(routes)
    OpenLibrary.fetcher = ->(uri) do
      _pattern, response = routes.find { |pattern, _| uri.to_s.include?(pattern) }
      raise "No fake Open Library response for #{uri}" unless response

      response.respond_to?(:call) ? response.call(uri) : response
    end
  end

  def open_library_json(docs)
    OpenLibrary::Response.new(code: 200, content_type: "application/json", location: nil, body: { docs: docs }.to_json)
  end

  def open_library_image(body = file_fixture("cover.jpg").binread)
    OpenLibrary::Response.new(code: 200, content_type: "image/jpeg", location: nil, body: body)
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include OpenLibraryTestHelper
  setup    { OpenLibrary.fetcher = OpenLibraryTestHelper::BLOCKED }
  teardown { OpenLibrary.fetcher = OpenLibraryTestHelper::BLOCKED }
end
