import { Controller } from "@hotwired/stimulus"

// Fills in the book form from Open Library when you enter an ISBN.
// Only empty fields are filled, so nothing you've typed is overwritten.
// Lives on the book <form>; the fields are its targets.
export default class extends Controller {
  static targets = [ "isbn", "title", "subtitle", "author", "year", "status", "button" ]
  static values = { url: String }

  // When you leave the ISBN box: look up automatically if it looks complete.
  isbnChanged() {
    if (this.#digits().length === 10 || this.#digits().length === 13) this.lookup()
  }

  // After a barcode scan: put the ISBN in the box and look it up.
  scanned({ detail: { isbn } }) {
    this.isbnTarget.value = isbn
    this.lookup()
  }

  // The "Look up" button (and after a scan or a typed ISBN).
  async lookup() {
    const isbn = this.#digits()
    if (isbn.length !== 10 && isbn.length !== 13) {
      return this.#say("Type the 10- or 13-digit ISBN first.", "error")
    }

    this.#say("Looking up this ISBN on Open Library…")
    this.buttonTarget.disabled = true
    try {
      const response = await fetch(`${this.urlValue}?isbn=${encodeURIComponent(isbn)}`, {
        headers: { Accept: "application/json" }
      })
      const data = await response.json()
      if (!response.ok) return this.#say(data.error, "error")
      this.#fill(data)
    } catch {
      this.#say("Couldn't look that up just now. Try again in a moment.", "error")
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  #fill(data) {
    const filled = []
    const fill = (target, value, label) => {
      if (value && !target.value.trim()) {
        target.value = value
        filled.push(label)
      }
    }
    fill(this.titleTarget, data.title, "title")
    fill(this.subtitleTarget, data.subtitle, "subtitle")
    fill(this.authorTarget, data.author, "author")
    fill(this.yearTarget, data.year, "year")

    // Tell the cover picker (it decides whether a cover is already chosen).
    if (data.cover_id) {
      this.dispatch("found", { target: window, detail: { coverId: data.cover_id, coverUrl: data.cover_url } })
    }

    this.#say(filled.length
      ? `Found “${data.title}”. Filled in: ${filled.join(", ")}.`
      : `Found “${data.title}”. Your details were already filled in, so nothing was changed.`, "success")
  }

  #digits() {
    return this.isbnTarget.value.toUpperCase().replace(/[^0-9X]/g, "")
  }

  #say(message, kind = "info") {
    this.statusTarget.textContent = message
    this.statusTarget.dataset.kind = kind
    this.statusTarget.hidden = false
  }
}
