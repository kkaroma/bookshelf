require "test_helper"

class Admin::GenresControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "lists genres in order with how many books use each" do
    books(:hobbit).update!(genre: "Fantasy")
    get admin_genres_url

    assert_response :success
    assert_select ".tabs a.active", "Genres"
    assert_select ".genre-row", Genre.count
    assert_select "#genre_#{genres(:fantasy).id} .genre-meta a[href=?]", books_path(genre: "Fantasy"), "1 book"
    assert_select "#genre_#{genres(:fantasy).id} button", text: "Delete", count: 0 # in use
    assert_select "#genre_#{genres(:cookery).id} button", "Delete"
    assert_select ".genre-row:first-child button[aria-label=?][disabled]", "Move Fiction up"
    assert_select "input#new_genre_name"
    assert_select "label[for=?]", "name_genre_#{genres(:fantasy).id}", "Name of Fantasy" # one label per box
  end

  test "add a genre, and refuse a duplicate" do
    assert_difference("Genre.count") { post admin_genres_url, params: { genre: { name: "Swahili literature" } } }
    assert_equal "Added “Swahili literature”.", flash[:notice]

    assert_no_difference("Genre.count") { post admin_genres_url, params: { genre: { name: "swahili LITERATURE" } } }
    assert_equal "Name already exists", flash[:alert]
  end

  test "rename a genre and its books" do
    books(:hobbit).update!(genre: "Fantasy")
    patch admin_genre_url(genres(:fantasy)), params: { genre: { name: "Fantasy & myth" } }

    assert_equal "Renamed “Fantasy” to “Fantasy & myth” on 1 book.", flash[:notice]
    assert_equal "Fantasy & myth", books(:hobbit).reload.genre
  end

  test "move, retire, restore and delete" do
    patch move_admin_genre_url(genres(:fantasy), direction: "up")
    assert_equal "Fantasy", Genre.names.first

    patch retire_admin_genre_url(genres(:fantasy))
    assert genres(:fantasy).reload.retired?
    get admin_genres_url
    assert_select "#genre_#{genres(:fantasy).id}.is-retired .badge", "Retired"

    patch restore_admin_genre_url(genres(:fantasy))
    assert_not genres(:fantasy).reload.retired?

    assert_difference("Genre.count", -1) { delete admin_genre_url(genres(:cookery)) }
  end

  test "a genre in use can't be deleted" do
    books(:hobbit).update!(genre: "Fantasy")
    assert_no_difference("Genre.count") { delete admin_genre_url(genres(:fantasy)) }
    assert_match(/Retire it instead/, flash[:alert])
  end

  test "retired genres disappear from the book form but stay on books that have them" do
    books(:hobbit).update!(genre: "Fantasy")
    genres(:fantasy).retire!
    sign_out
    sign_in_as users(:one)

    get new_book_url
    assert_select "select[name=?] option", "book[genre]", text: "Fantasy", count: 0
    get edit_book_url(books(:hobbit))
    assert_select "select[name=?] option[selected]", "book[genre]", "Fantasy"
  end

  test "members get page not found" do
    sign_out
    sign_in_as users(:one)
    get admin_genres_url
    assert_response :not_found
    post admin_genres_url, params: { genre: { name: "Spam" } }
    assert_response :not_found
    assert_not Genre.exists?(name: "Spam")
  end
end
