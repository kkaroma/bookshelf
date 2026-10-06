# My wishlist: books I'd like, and whether anyone is offering them right now.
class WishlistItemsController < ApplicationController
  def index
    @items = Current.user.wishlist_items
    @item = WishlistItem.new
  end

  # From the form on the Wishlist page, or the "Add to my wishlist" button on a book.
  def create
    # Built on its own (not via Current.user.wishlist_items.build) so that, if it
    # fails validation, the unsaved entry doesn't appear in the list below the form.
    @item = WishlistItem.new(params.expect(wishlist_item: [ :title, :author, :isbn ]).merge(user: Current.user))
    if @item.save
      redirect_back_or_to wishlist_items_path, notice: "“#{@item.title}” is on your wishlist. We'll tell you when someone offers it."
    else
      @items = Current.user.wishlist_items
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    item = Current.user.wishlist_items.find(params.expect(:id))
    item.destroy
    redirect_back_or_to wishlist_items_path, notice: "“#{item.title}” was removed from your wishlist.", status: :see_other
  end
end
