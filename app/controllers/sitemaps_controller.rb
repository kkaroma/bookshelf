# /sitemap.xml - the public pages search engines may list: public members'
# profiles and their books. Nothing else.
class SitemapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @members = User.publicly_visible.order(:id)
    @books = Book.joins(:user).merge(User.publicly_visible).order(:id).select(:id, :title, :updated_at)
  end
end
