import { Controller } from "@hotwired/stimulus"

// The cover section of the book form. Either upload a file or pick a cover
// found on Open Library; the preview shows whichever was chosen last.
export default class extends Controller {
  static targets = [ "preview", "file", "coverId", "results" ]
  static values = { searchUrl: String }

  // "Find cover online": load results into the Turbo Frame using what's
  // typed in the form so far.
  search() {
    const params = new URLSearchParams({
      isbn:   this.#field("isbn"),
      title:  this.#field("title"),
      author: this.#field("author")
    })
    this.resultsTarget.innerHTML = `<p class="cover-results-message">Searching Open Library…</p>`
    this.resultsTarget.src = `${this.searchUrlValue}?${params}`
  }

  // Clicking one of the results.
  pick({ currentTarget, params: { id, url, isbn } }) {
    this.coverIdTarget.value = id
    this.fileTarget.value = ""
    this.#showPreview(url)

    this.resultsTarget.querySelectorAll(".cover-result").forEach((button) => {
      button.setAttribute("aria-pressed", button === currentTarget)
    })

    // Fill in the ISBN too, if it's still empty.
    const isbnField = this.#input("isbn")
    if (isbn && isbnField && !isbnField.value) isbnField.value = isbn
  }

  // Choosing a file to upload.
  uploaded() {
    const file = this.fileTarget.files[0]
    if (!file) return

    this.coverIdTarget.value = ""
    this.resultsTarget.querySelectorAll(".cover-result").forEach((button) => {
      button.setAttribute("aria-pressed", false)
    })
    this.#showPreview(URL.createObjectURL(file))
  }

  #showPreview(url) {
    const image = document.createElement("img")
    image.src = url
    image.alt = "Chosen cover"
    this.previewTarget.replaceChildren(image)
  }

  #input(name) {
    return this.element.closest("form").querySelector(`[name="book[${name}]"]`)
  }

  #field(name) {
    return this.#input(name)?.value.trim() ?? ""
  }
}
