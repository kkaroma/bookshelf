module ApplicationHelper
  # "Alice Reader" -> "AR"
  def initials(name)
    name.to_s.split.first(2).map { |word| word[0] }.join.upcase
  end

  # Rounds an average to the nearest half star: 4.3 -> 4.5, 4.2 -> 4.0
  def round_to_half(average)
    (average.to_f * 2).round / 2.0
  end

  # Five stars for an average rating, each one full, half or empty:
  #   4.5 -> ★★★★ + half star
  # Screen readers hear "Rated 4.5 out of 5" instead of five star symbols.
  def star_rating(average)
    rounded = round_to_half(average)

    stars = (1..5).map do |position|
      kind =
        if rounded >= position then "full"
        elsif rounded >= position - 0.5 then "half"
        else "empty"
        end
      tag.span("★", class: "star-#{kind}")
    end

    tag.span(safe_join(stars), class: "stars-display", role: "img",
             aria: { label: "Rated #{average} out of 5" })
  end

  # A stable avatar colour per user (0-359 on the colour wheel).
  def avatar_hue(user)
    (user.id * 47) % 360
  end
end
