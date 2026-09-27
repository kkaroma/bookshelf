require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "round_to_half rounds to the nearest half star" do
    assert_equal 4.5, round_to_half(4.5)
    assert_equal 4.5, round_to_half(4.3)
    assert_equal 4.0, round_to_half(4.2)
    assert_equal 5.0, round_to_half(4.8)
    assert_equal 1.0, round_to_half(1.0)
  end

  test "star_rating shows full, half and empty stars" do
    html = star_rating(3.5)
    assert_equal 3, html.scan("star-full").size
    assert_equal 1, html.scan("star-half").size
    assert_equal 1, html.scan("star-empty").size
  end

  test "star_rating with a whole number has no half star" do
    html = star_rating(4.0)
    assert_equal 4, html.scan("star-full").size
    assert_equal 0, html.scan("star-half").size
    assert_equal 1, html.scan("star-empty").size
  end

  test "star_rating of 5 is all full stars" do
    assert_equal 5, star_rating(5.0).scan("star-full").size
  end

  test "star_rating describes itself for screen readers" do
    assert_includes star_rating(4.5), 'aria-label="Rated 4.5 out of 5"'
    assert_includes star_rating(4.5), 'role="img"'
  end

  test "initials uses the first letters of up to two words" do
    assert_equal "AR", initials("Alice Reader")
    assert_equal "M", initials("Madonna")
    assert_equal "JR", initials("J. R. R. Tolkien")
  end
end
