module FlagsHelper
  # The parameter that names a reported thing in a URL, e.g. { comment_id: 3 }.
  def flaggable_param(item)
    case item
    when Book          then { book_id: item.id }
    when Comment       then { comment_id: item.id }
    when DirectMessage then { message_id: item.id }
    end
  end
end
