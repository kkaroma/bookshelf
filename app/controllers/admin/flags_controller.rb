# /admin/flags - books and comments members have reported. For each one an
# admin either removes it or dismisses the reports.
class Admin::FlagsController < Admin::BaseController
  include FlaggableLookup
  before_action :set_flaggable, only: %i[ dismiss remove ]

  def index
    # One entry per reported thing, oldest report first, with all its reports.
    flags = Flag.unresolved.includes(:reporter, :flaggable).order(:created_at)
    @reported = flags.group_by(&:flaggable)
    @recently_dismissed = Flag.where.not(resolved_at: nil).includes(:reporter, :resolved_by, :flaggable)
                              .order(resolved_at: :desc).limit(10)
  end

  def dismiss
    count = Flag.dismiss_all_for(@flaggable, by: Current.user)
    redirect_to admin_flags_path, notice: "Dismissed #{view_context.pluralize(count, "report")}. Nothing was removed."
  end

  # Deleting the book, comment or message deletes its reports too.
  def remove
    @flaggable.destroy!
    what = case @flaggable
    when Book          then "The book “#{@flaggable.title}”"
    when Comment       then "The comment"
    when DirectMessage then "The private message"
    end
    redirect_to admin_flags_path, notice: "#{what} was removed.", status: :see_other
  end

  private
    def set_flaggable
      @flaggable = find_flaggable
    end
end
