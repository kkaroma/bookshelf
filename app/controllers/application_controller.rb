class ApplicationController < ActionController::Base
  include Authentication
  include EmailConfirmationRequired
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # If this request crashes, the error email says which page and member.
  before_action { Rails.error.set_context(url: request.url, user_id: Current.user&.id) }

  # Bots and link previews sometimes ask for a page as JSON or XML. Pages here
  # only exist as HTML (and Turbo Stream), so say "not acceptable" instead of
  # crashing with a missing template - which would also send an error email.
  # A template genuinely missing from an HTML page is still a real error.
  rescue_from ActionView::MissingTemplate do |error|
    raise error if request.format.html? || request.format.turbo_stream?

    head :not_acceptable
  end
end
