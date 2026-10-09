class ApplicationController < ActionController::Base
  include Authentication
  include EmailConfirmationRequired
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # If this request crashes, the error email says which page and member.
  before_action { Rails.error.set_context(url: request.url, user_id: Current.user&.id) }
end
