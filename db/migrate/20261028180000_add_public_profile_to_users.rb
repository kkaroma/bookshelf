# Members can make their profile and reviews public (readable without an
# account, shareable, findable on Google). Off for everyone until they choose.
class AddPublicProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :public_profile, :boolean, default: false, null: false
    add_column :users, :public_profile_asked_at, :datetime # when they answered "Make my profile public?"
    add_index :users, :public_profile
  end
end
