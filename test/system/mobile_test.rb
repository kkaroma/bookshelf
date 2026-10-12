require "application_system_test_case"

# The site on a phone-sized screen (390px, like an iPhone), using Chrome's
# phone emulation - a desktop window can't be made that narrow.
class MobileTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  # The browser is reused by later tests, so put it back to desktop size.
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") unless chrome_crashed?
  end

  def sign_in_on_phone(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".account-menu summary" # the phone header
  end

  def assert_fits_the_screen
    widths = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    assert_operator widths[0], :<=, widths[1], "#{current_path} is wider than the screen (#{widths[0]}px > #{widths[1]}px)"
  end

  test "pages fit the screen without sideways scrolling" do
    visit root_path
    assert_fits_the_screen

    sign_in_on_phone users(:one)
    [ root_path, books_path, book_path(books(:dune)), new_book_path, exchanges_path,
      exchange_requests_path, users_path, user_path(users(:two)), notifications_path,
      wishlist_items_path, edit_settings_profile_path ].each do |path|
      visit path
      assert_fits_the_screen
    end
  end

  test "the compact header: + adds a book, the account menu signs out" do
    sign_in_on_phone users(:one)

    # The wide header's name and Sign out are hidden; the + button replaces "Add a book".
    assert_no_selector ".nav-user-name"
    assert_no_button "Sign out"
    assert_no_text "Add a book"
    click_on "Add a book" # found by its label
    assert_selector "h1", text: "Add a book"

    find(".account-menu summary").click
    within(".account-menu") do
      assert_text "Alice Reader"
      assert_link "My profile", href: user_path(users(:one))
      assert_link "Settings"
      click_on "Sign out"
    end
    assert_text "You have been signed out."
  end

  test "the account menu closes when you tap elsewhere" do
    sign_in_on_phone users(:one)
    find(".account-menu summary").click
    assert_selector ".account-menu[open]"

    find(".site-footer").click
    assert_no_selector ".account-menu[open]"
  end

  test "books show two to a row" do
    sign_in_on_phone users(:one)
    visit books_path

    tops = all("#books .book-card").map { |card| card.evaluate_script("this.getBoundingClientRect().top").round }
    assert_equal 2, tops.size
    assert_equal tops.first, tops.last, "the two books should sit side by side"
  end

  test "form fields use 16px text so iPhones don't zoom in" do
    sign_in_on_phone users(:one)
    visit books_path
    assert_equal "16px", find("input[name=q]").evaluate_script("getComputedStyle(this).fontSize")
    assert_equal "16px", find("select[name=genre]").evaluate_script("getComputedStyle(this).fontSize")
  end
end
