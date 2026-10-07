# Something members can report to the admins (books and comments).
# A *concern* is a module of shared model code: `include Flaggable` gives a
# model everything below.
module Flaggable
  extend ActiveSupport::Concern

  included do
    has_many :flags, as: :flaggable, dependent: :destroy
  end

  # Members can report other people's things. Admins don't need to - they
  # can remove things themselves - and nobody reports their own.
  def flaggable_by?(someone)
    someone.present? && !someone.admin? && user_id != someone.id
  end
end
