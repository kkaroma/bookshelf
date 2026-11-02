require "application_system_test_case"

# Home's "Your books" always shows whole rows: 2 rows of 6 on wide screens,
# 2 rows of 4 on tablets, 3 rows of 2 on phones.
class HomeShelfTest < ApplicationSystemTestCase
  setup do
    14.times { |i| Book.create!(user: users(:one), title: format("Shelf book %02d", i), author: "A") }
    sign_in_as users(:one)
  end

  def visible_rows
    tops = all("#my_books .book-card").map { |card| card.evaluate_script("Math.round(this.getBoundingClientRect().top)") }
    tops.tally.values # books per row
  end

  test "two full rows of six on a wide screen" do
    visit root_path
    assert_equal [ 6, 6 ], visible_rows
  end

  test "two full rows of four on a tablet" do
    # Emulate the screen rather than resizing the real window, which can leak
    # into the next test (ApplicationSystemTestCase resets emulation).
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 800, height: 900, deviceScaleFactor: 1, mobile: false)
    visit root_path
    assert_equal [ 4, 4 ], visible_rows
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "three rows of two on a phone" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    visit root_path
    assert_equal [ 2, 2, 2 ], visible_rows
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
