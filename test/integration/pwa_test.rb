require "test_helper"

# "Install as an app": manifest, icons, service worker and offline page.
class PwaTest < ActionDispatch::IntegrationTest
  test "the manifest names the app and lists icons that exist" do
    get pwa_manifest_url(format: :json)
    assert_response :success

    manifest = JSON.parse(response.body)
    assert_equal "Bookshelf", manifest["name"]
    assert_equal "standalone", manifest["display"]
    assert_equal [ "192x192", "512x512", "512x512" ], manifest["icons"].map { |icon| icon["sizes"] }
    assert manifest["icons"].any? { |icon| icon["purpose"] == "maskable" }
    manifest["icons"].each do |icon|
      assert Rails.public_path.join(icon["src"].delete_prefix("/")).exist?, "missing #{icon["src"]}"
    end
  end

  test "the service worker is served and caches the offline page" do
    get pwa_service_worker_url(format: :js)
    assert_response :success
    assert_match "/offline.html", response.body
    assert Rails.public_path.join("offline.html").exist?
  end

  test "every page links the manifest and icons, signed in or not" do
    get root_url
    assert_select "link[rel=manifest][href=?]", pwa_manifest_path(format: :json)
    assert_select "link[rel=apple-touch-icon][href=?]", "/apple-touch-icon.png"
    assert_select "meta[name=theme-color]"

    sign_in_as users(:one)
    get books_url
    assert_select "link[rel=manifest]"
  end
end
