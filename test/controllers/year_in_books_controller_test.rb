require "test_helper"

class YearInBooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:one)
    sign_in_as @alice
  end

  test "this year's page with highlights" do
    Book.create!(user: @alice, title: "Emma", author: "Jane Austen", genre: "Fiction",
                 reading_status: :read, finished_on: Date.current)
    get year_in_books_url

    assert_response :success
    assert_select "h1", "My #{Date.current.year} in books"
    assert_select "#books_read_count", "1"
    assert_select "#read_chart_title", "Books finished each month"
    assert_select ".year-genres li", /Fiction\s+1 book/
    assert_select "#books .book-card", 1
  end

  test "an earlier year, with links between years" do
    Book.create!(user: @alice, title: "Old", author: "A", reading_status: :read, finished_on: Date.new(2024, 5, 1))
    get year_in_books_url(year: 2024)

    assert_select "h1", "My 2024 in books"
    assert_select ".period-choice.active", "2024"
    assert_select ".period-choice[href=?]", year_in_books_path(year: Date.current.year)
  end

  test "a year with nothing in it" do
    get year_in_books_url(year: 2019)
    assert_select ".empty-state h2", "Nothing here yet"
  end

  test "future and silly years aren't found" do
    get year_in_books_url(year: Date.current.year + 1)
    assert_response :not_found
    get "/year-in-books/1066"
    assert_response :not_found
  end

  test "it's always your own year" do
    get year_in_books_url(user_id: users(:two).id)
    assert_select "p", /#{@alice.name.split.first}\. Only you can see this page/
  end

  test "Home and the phone menu link to it" do
    get root_url
    assert_select ".welcome a[href=?]", year_in_books_path, "My year in books"
    assert_select ".account-menu a[href=?]", year_in_books_path
  end

  test "visitors are sent to sign in" do
    sign_out
    get year_in_books_url
    assert_redirected_to new_session_url
  end

  test "swaps read naturally" do
    request = ExchangeRequest.create!(requester: @alice, book: books(:dune), offered_book: books(:hobbit))
    request.update_columns(status: ExchangeRequest.statuses[:completed], completed_at: Time.current)
    get year_in_books_url
    assert_select ".year-swaps li", /Swapped The Hobbit for Dune with Bob Bookworm/

    sign_out
    sign_in_as users(:admin) # gave nothing back: the admin only received
    ExchangeRequest.create!(requester: users(:admin), book: Book.create!(user: users(:two), title: "Emma", author: "A", available_for_exchange: true))
                   .update_columns(status: ExchangeRequest.statuses[:completed], completed_at: Time.current)
    get year_in_books_url
    assert_select ".year-swaps li", /Got Emma from Bob Bookworm/
  end

  test "the monthly chart has twelve columns in one row" do
    Book.create!(user: @alice, title: "Emma", author: "A", reading_status: :read, finished_on: Date.current)
    get year_in_books_url
    assert_select "figure.chart[style=?]", "--columns: 12"
    assert_select "figure[aria-labelledby=read_chart_title] .chart-col", 12
  end
end
