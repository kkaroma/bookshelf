module NotificationsHelper
  # What a notification says, e.g. "<strong>Bob</strong> commented on <strong>The Hobbit</strong>".
  def notification_message(notification)
    actor = tag.strong(notification.actor&.name || "Someone")
    about = notification.notifiable

    case notification.kind
    when "exchange_request_received" then safe_join([ actor, " wants to swap for your book ", book_title(about.book) ])
    when "exchange_request_accepted" then safe_join([ actor, " accepted your request for ", book_title(about.book) ])
    when "exchange_request_declined" then safe_join([ "Your request for ", book_title(about.book), " was declined" ])
    when "swap_completed"            then safe_join([ actor, " marked your swap of ", book_title(about.book), " as done" ])
    when "new_message"               then safe_join([ actor, " sent you a message about ", book_title(about.exchange_request.book) ])
    when "new_comment"               then safe_join([ actor, " commented on ", book_title(about.book) ])
    when "new_reply"                 then safe_join([ actor, " replied to your comment on ", book_title(about.book) ])
    when "new_follower"              then safe_join([ actor, " started following you" ])
    when "wishlist_match"            then safe_join([ book_title(about), ", on your wishlist, is now on the Exchange shelf (offered by ", tag.strong(about.user.name), ")" ])
    end
  end

  # Where clicking a notification takes you.
  def notification_target_path(notification)
    about = notification.notifiable

    case notification.kind
    when "exchange_request_received"                              then exchange_requests_path
    when "exchange_request_accepted", "exchange_request_declined" then exchange_requests_path(box: "sent")
    when "swap_completed"                                         then exchange_request_path(about)
    when "new_message"                                            then exchange_request_path(about.exchange_request, anchor: dom_id(about))
    when "new_comment", "new_reply"                               then book_path(about.book, anchor: dom_id(about))
    when "new_follower"                                           then user_path(notification.actor || notification.recipient)
    when "wishlist_match"                                         then book_path(about)
    end
  end

  private
    def book_title(book) = tag.strong(book.title)
end
