# What the people I follow have been doing, newest first: books they added,
# reviews they wrote, ratings they gave and swaps they completed.
#
#   ActivityFeed.new(Current.user).events  # => [Event, ...]
class ActivityFeed
  Event = Data.define(:kind, :actor, :book, :at, :detail)

  def initialize(user, limit: 15)
    @user = user
    @limit = limit
  end

  def events
    (added + reviewed + rated + swapped).sort_by(&:at).reverse.first(@limit)
  end

  private
    def followed_ids
      @followed_ids ||= @user.active_follows.pluck(:followed_id)
    end

    def books_by_followed
      Book.where(user_id: followed_ids).includes(:user).with_attached_cover
    end

    def added
      books_by_followed.order(created_at: :desc).limit(@limit)
                       .map { |book| Event.new(:added, book.user, book, book.created_at, nil) }
    end

    def reviewed
      books_by_followed.where.not(reviewed_at: nil).where.not(review: nil).order(reviewed_at: :desc).limit(@limit)
                       .map { |book| Event.new(:reviewed, book.user, book, book.reviewed_at, book.review.truncate(140)) }
    end

    def rated
      Rating.where(user_id: followed_ids).includes(:user, book: { cover_attachment: :blob }).order(created_at: :desc).limit(@limit)
            .map { |rating| Event.new(:rated, rating.user, rating.book, rating.created_at, rating.score) }
    end

    # A completed swap, told from the side of the person I follow.
    def swapped
      ExchangeRequest.completed.where(requester_id: followed_ids).or(ExchangeRequest.completed.where(owner_id: followed_ids))
                     .includes(:requester, :owner, book: { cover_attachment: :blob }).order(completed_at: :desc).limit(@limit)
                     .map do |swap|
        actor, other = followed_ids.include?(swap.requester_id) ? [ swap.requester, swap.owner ] : [ swap.owner, swap.requester ]
        Event.new(:swapped, actor, swap.book, swap.completed_at, other)
      end
    end
end
