# Members reporting a book or comment to the admins.
#   GET  /flags/new?book_id=1  (or ?comment_id=3) - the form
#   POST /flags?book_id=1                         - send the report
class FlagsController < ApplicationController
  before_action :require_confirmed_email
  before_action :set_flaggable
  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to root_path, alert: "You've sent a lot of reports. Please try again later." }

  def new
    @flag = Flag.new
  end

  def create
    @flag = Flag.new(params.expect(flag: [ :reason, :note ]).merge(reporter: Current.user, flaggable: @flaggable))

    if @flag.save
      redirect_to back_path, notice: "Thanks for letting us know. An admin will take a look."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to back_path, notice: "You've already reported this. An admin will look at it soon."
  end

  private
    # Only books and comments can be reported; which one comes from the
    # parameter name, never from a class name typed into the address bar.
    def set_flaggable
      @flaggable = params[:comment_id] ? Comment.find(params[:comment_id]) : Book.find(params.expect(:book_id))

      unless @flaggable.flaggable_by?(Current.user)
        redirect_to back_path, alert: "You can't report this."
      end
    end

    def back_path
      @flaggable.is_a?(Comment) ? book_path(@flaggable.book, anchor: helpers.dom_id(@flaggable)) : book_path(@flaggable)
    end

    helper_method :back_path
end
