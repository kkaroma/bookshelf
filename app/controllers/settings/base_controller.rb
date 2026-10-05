# Parent of the Settings pages. Every settings page works on the signed-in
# member's own account, available as @user.
class Settings::BaseController < ApplicationController
  # A separate copy of the record, so unsaved form changes (e.g. a blank name
  # that fails validation) don't leak into the header, which uses Current.user.
  before_action { @user = User.find(Current.user.id) }
end
