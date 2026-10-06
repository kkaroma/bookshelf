require "test_helper"

class Books::ReadingStatusesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hobbit = books(:hobbit) # Alice's
    sign_in_as users(:one)
  end

  test "mark your book as reading, then read" do
    travel_to Date.new(2026, 10, 1) do
      patch book_reading_status_url(@hobbit), params: { reading_status: "reading" }
      assert_redirected_to book_url(@hobbit)
      assert @hobbit.reload.reading?
      assert_equal Date.new(2026, 10, 1), @hobbit.started_on
    end

    travel_to Date.new(2026, 10, 9) do
      patch book_reading_status_url(@hobbit), params: { reading_status: "read" }
      @hobbit.reload
      assert @hobbit.read?
      assert_equal Date.new(2026, 10, 1), @hobbit.started_on # kept
      assert_equal Date.new(2026, 10, 9), @hobbit.finished_on
    end
  end

  test "clearing the status clears the dates" do
    @hobbit.update_reading_status!("read")
    patch book_reading_status_url(@hobbit), params: { reading_status: "" }
    @hobbit.reload
    assert_nil @hobbit.reading_status
    assert_nil @hobbit.finished_on
  end

  test "unknown statuses are ignored, not errors" do
    patch book_reading_status_url(@hobbit), params: { reading_status: "devoured" }
    assert_redirected_to book_url(@hobbit)
    assert_nil @hobbit.reload.reading_status
  end

  test "you can only set the status of your own books" do
    patch book_reading_status_url(books(:dune)), params: { reading_status: "read" } # Bob's
    assert_response :not_found
    assert_nil books(:dune).reload.reading_status
  end

  test "the owner sees the buttons; others see a label" do
    @hobbit.update_reading_status!("reading")

    get book_url(@hobbit)
    assert_select ".status-buttons button", 3
    assert_select ".status-button.is-current[aria-pressed=true]", "Reading"

    sign_out
    sign_in_as users(:two)
    get book_url(@hobbit)
    assert_select ".status-buttons", count: 0
    assert_select ".pill", "Alice is reading this"
  end

  test "book cards show the status" do
    @hobbit.update_reading_status!("read")
    get books_url
    assert_select "#book_#{@hobbit.id} .book-card-status", "Read"
  end
end
