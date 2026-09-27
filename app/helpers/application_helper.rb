module ApplicationHelper
  # "Alice Reader" -> "AR"
  def initials(name)
    name.to_s.split.first(2).map { |word| word[0] }.join.upcase
  end

  # A stable avatar colour per user (0-359 on the colour wheel).
  def avatar_hue(user)
    (user.id * 47) % 360
  end
end
