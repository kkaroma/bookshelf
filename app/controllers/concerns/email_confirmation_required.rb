# Members must confirm their email address before they can write things other
# people see (comments, swap requests, messages, reports). This keeps out
# spam accounts made with made-up addresses.
#
#   before_action :require_confirmed_email, only: :create
module EmailConfirmationRequired
  extend ActiveSupport::Concern

  private
    def require_confirmed_email
      return if Current.user.email_confirmed?

      redirect_back_or_to root_path,
        alert: "Please confirm your email address first — use the link we emailed to #{Current.user.email_address}."
    end
end
