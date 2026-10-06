import { Controller } from "@hotwired/stimulus"

// Submits the search form shortly after the person stops typing (or at once
// when a filter changes), so results
// update as they type without sending a request for every key press. The
// results load into a Turbo Frame; this controller keeps the address bar in
// step (so reloading or sharing the page keeps the search).
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  // data-action="input->search#queue"
  queue() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submitNow(), this.delayValue)
  }

  // data-action="search->search#submitNow": the browser's "search" event fires
  // when the little ✕ in the search box clears it, or on Enter.
  submitNow() {
    clearTimeout(this.timeout)
    this.#updateAddressBar()
    this.element.requestSubmit()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Replace (not add) the history entry: typing shouldn't make the Back button
  // step through every search. Keeping history.state preserves Turbo's own data.
  // Every filled-in field (search, genre, sort…) goes into the address.
  #updateAddressBar() {
    const url = new URL(this.element.action, window.location.href)
    for (const [ name, value ] of new FormData(this.element)) {
      const text = String(value).trim()
      if (text && !(name === "sort" && text === "title")) url.searchParams.set(name, text) // title is the default sort
    }
    history.replaceState(history.state, "", url)
  }
}
