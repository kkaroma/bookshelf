class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_authenticated
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  # Spam protection. Real people take a few seconds to fill in the form;
  # sign-up robots post it instantly. (Tests set this to 0.)
  class_attribute :minimum_fill_time, default: 3.seconds

  # Signs the time the form was shown, so it can't be faked.
  def self.form_timer = Rails.application.message_verifier(:sign_up_form)

  # The value for the form's hidden field, made when the form is shown.
  def self.form_started_token(at = Time.current)
    form_timer.generate(at.to_i, expires_in: 1.day)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if (problem = spam_problem)
      @user.errors.add(:base, problem)
      render :new, status: :unprocessable_content
    elsif @user.save
      start_new_session_for @user
      redirect_to root_path,
                  notice: "Welcome to Bookshelf, #{@user.name}! We've emailed a link to #{@user.email_address} — open it to confirm your address."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
    end

    # Two checks robots usually fail:
    # 1. a "honeypot" field hidden from people, which robots fill in;
    # 2. the form must have been on screen for a few seconds. The time it was
    #    shown travels in a signed field, so it can't be faked.
    def spam_problem
      if params[:website].present?
        "We couldn't create your account. Please try again."
      elsif (shown_at = form_shown_at).nil?
        "The form expired. Please try again."
      elsif Time.current - shown_at < minimum_fill_time
        "That was quick! Please check your details and press “Create account” again."
      end
    end

    def form_shown_at
      seconds = self.class.form_timer.verified(params[:form_started].to_s)
      Time.zone.at(seconds) if seconds.is_a?(Integer)
    end
end
