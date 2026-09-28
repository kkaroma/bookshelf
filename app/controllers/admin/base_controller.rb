# Parent of every admin-only page. Anyone who isn't an admin gets a plain
# "page not found", so members don't even learn the admin pages exist.
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      unless Current.user&.admin?
        render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
      end
    end
end
