module YearInBooksHelper
  # "Swapped Emma for Dune with Bob", "Got Dune from Bob" or "Gave Emma to Bob".
  def swap_sentence(swap)
    person = link_to(swap.with.name, swap.with)
    if swap.received && swap.gave
      safe_join([ "Swapped ", link_to(swap.gave.title, swap.gave), " for ", link_to(swap.received.title, swap.received), " with ", person ])
    elsif swap.received
      safe_join([ "Got ", link_to(swap.received.title, swap.received), " from ", person ])
    else
      safe_join([ "Gave ", link_to(swap.gave.title, swap.gave), " to ", person ])
    end
  end
end
