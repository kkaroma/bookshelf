require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    sign_in_as @alice
  end

  test "the wishlist shows what's available now" do
    @alice.wishlist_items.create!(title: "Dune")
    @alice.wishlist_items.create!(title: "Middlemarch")

    get wishlist_items_url
    assert_select ".wishlist-item", 2
    assert_select ".wishlist-item.is-available", /Dune.*Available now from\s+Bob Bookworm/m
    assert_select ".wishlist-item.is-available a[href=?]", new_book_exchange_request_path(books(:dune)), text: "Request exchange"
    assert_select ".wishlist-item:not(.is-available)", /Middlemarch.*Not on the Exchange shelf yet/m
  end

  test "add and remove" do
    post wishlist_items_url, params: { wishlist_item: { title: "Emma", author: "Jane Austen" } }
    assert_redirected_to wishlist_items_path
    item = @alice.wishlist_items.last
    assert_equal "Emma", item.title

    delete wishlist_item_url(item)
    assert_not WishlistItem.exists?(item.id)
  end

  test "a bad entry shows errors" do
    post wishlist_items_url, params: { wishlist_item: { title: "" } }
    assert_response :unprocessable_content
    assert_select ".form-errors", /Title can't be blank/
  end

  test "you can't remove someone else's wishlist entry" do
    other = users(:two).wishlist_items.create!(title: "Emma")
    delete wishlist_item_url(other)
    assert_response :not_found
  end

  test "other members' books not on the shelf offer 'Add to my wishlist'" do
    sign_out
    sign_in_as users(:two)
    get book_url(books(:hobbit)) # Alice's, not offered
    assert_select ".wishlist-panel button", "Add to my wishlist"

    post wishlist_items_url, params: { wishlist_item: { title: "The Hobbit", author: "J.R.R. Tolkien" } },
         headers: { "Referer" => book_url(books(:hobbit)) }
    assert_redirected_to book_url(books(:hobbit))
    get book_url(books(:hobbit))
    assert_select ".wishlist-panel", /on your\s+wishlist/
  end

  test "the Exchange shelf links to the wishlist" do
    get exchanges_url
    assert_select "a[href=?]", wishlist_items_path, text: /My wishlist/
  end
end
