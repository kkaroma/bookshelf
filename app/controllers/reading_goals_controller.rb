# Sets or removes the signed-in member's reading goal for this year. The Home
# page shows it in a Turbo Frame, so after each change we redirect back there
# and only the goal card is refreshed.
class ReadingGoalsController < ApplicationController
  def update
    goal = Current.user.reading_goals.find_or_initialize_by(year: Date.current.year)
    goal.target = params.dig(:reading_goal, :target)

    if goal.save
      redirect_to root_path
    else
      redirect_to root_path, alert: "Reading goal #{goal.errors[:target].first}."
    end
  end

  def destroy
    Current.user.reading_goal_for&.destroy
    redirect_to root_path, status: :see_other
  end
end
