module HomeHelper
  # One line of the activity feed, e.g. "Bob added The Hobbit".
  def feed_sentence(event)
    actor = link_to(event.actor.name, event.actor, class: "feed-actor")
    book = link_to(event.book.title, event.book)

    case event.kind
    when :added    then safe_join([ actor, " added ", book ])
    when :reviewed then safe_join([ actor, " reviewed ", book ])
    when :rated
      stars = tag.span(class: "feed-stars", aria: { label: "#{event.detail} out of 5" }) do
        safe_join([ "★" * event.detail, tag.span("★" * (5 - event.detail), class: "star-empty") ])
      end
      safe_join([ actor, " rated ", book, " ", stars ])
    when :swapped  then safe_join([ actor, " swapped ", book, " with ", link_to(event.detail.name, event.detail) ])
    end
  end
end
