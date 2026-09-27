require "net/http"

# Talks to Open Library (openlibrary.org), a free book catalogue run by the
# Internet Archive. Used to search for book covers and download the one a
# member picks. No account or API key is needed.
module OpenLibrary
  SEARCH_URL = "https://openlibrary.org/search.json".freeze
  MAX_COVER_BYTES = 5.megabytes
  MAX_REDIRECTS = 3

  # Anything that goes wrong talking to Open Library (network down, slow,
  # unexpected answer) is raised as this one error type.
  class Error < StandardError; end

  # One answer from Open Library: what a single HTTP request returned.
  Response = Data.define(:code, :content_type, :location, :body)

  # One search result the member can pick.
  Result = Data.define(:cover_id, :title, :author, :year, :isbn) do
    def thumbnail_url = OpenLibrary.cover_url(cover_id, size: "M")
  end

  # How we make a single HTTP GET request. Tests swap this for a fake so they
  # never touch the real internet.
  mattr_accessor :fetcher, default: ->(uri) {
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      response = http.request(Net::HTTP::Get.new(uri, "User-Agent" => "Bookshelf (personal book catalogue)"))
      Response.new(code: response.code.to_i, content_type: response["content-type"],
                   location: response["location"], body: response.body)
    end
  }

  class << self
    # Search by ISBN if we have one (most accurate), otherwise by title and author.
    # Returns up to `limit` results that have a cover.
    def search(title: nil, author: nil, isbn: nil, limit: 8)
      query = { fields: "title,author_name,cover_i,first_publish_year,isbn", limit: limit * 2 }
      if isbn.present?
        query[:q] = "isbn:#{isbn.to_s.gsub(/[^0-9Xx]/, "")}"
      elsif title.present?
        query[:title] = title
        query[:author] = author if author.present?
      else
        return []
      end

      docs = JSON.parse(fetch(URI("#{SEARCH_URL}?#{query.to_query}")).body).fetch("docs", [])
      docs.filter_map { |doc| result_from(doc) }.uniq(&:cover_id).first(limit)
    rescue JSON::ParserError
      raise Error, "Open Library sent an answer we couldn't read"
    end

    def cover_url(cover_id, size: "L")
      "https://covers.openlibrary.org/b/id/#{Integer(cover_id)}-#{size}.jpg"
    end

    # Downloads a cover by its Open Library ID, ready to attach with Active Storage.
    def download_cover(cover_id)
      # default=false makes Open Library answer 404 instead of a blank image
      response = fetch(URI("#{cover_url(cover_id)}?default=false"))

      unless response.content_type.to_s.start_with?("image/jpeg")
        raise Error, "Open Library didn't send an image"
      end
      if response.body.bytesize > MAX_COVER_BYTES
        raise Error, "that cover image is too large"
      end

      { io: StringIO.new(response.body), filename: "cover-#{Integer(cover_id)}.jpg", content_type: "image/jpeg" }
    end

    private
      # Makes the request, following a few redirects (covers are served from
      # archive.org), but only ever to Open Library / Internet Archive servers.
      def fetch(uri, redirects_left: MAX_REDIRECTS)
        raise Error, "refusing to contact #{uri.host}" unless allowed?(uri)

        response = fetcher.call(uri)
        case response.code
        when 200
          response
        when 301, 302, 303, 307, 308
          raise Error, "too many redirects" if redirects_left.zero?
          fetch(URI.join(uri, response.location), redirects_left: redirects_left - 1)
        else
          raise Error, "Open Library answered with status #{response.code}"
        end
      rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => error
        raise Error, "couldn't reach Open Library (#{error.class.name})"
      end

      def allowed?(uri)
        host = uri.host.to_s
        uri.scheme == "https" &&
          %w[ openlibrary.org archive.org ].any? { |domain| host == domain || host.end_with?(".#{domain}") }
      end

      def result_from(doc)
        return unless doc["cover_i"]

        isbns = Array(doc["isbn"])
        Result.new(
          cover_id: doc["cover_i"],
          title: doc["title"],
          author: Array(doc["author_name"]).first,
          year: doc["first_publish_year"],
          isbn: isbns.find { |isbn| isbn.length == 13 } || isbns.first
        )
      end
  end
end
