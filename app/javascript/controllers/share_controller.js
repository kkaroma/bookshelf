import { Controller } from "@hotwired/stimulus"

// The Share button on public pages: opens the phone's share menu (WhatsApp,
// SMS, …) where the browser has one, otherwise copies the link.
export default class extends Controller {
  static values = { url: String, title: String }
  static targets = [ "done" ]

  async share() {
    if (navigator.share) {
      try {
        await navigator.share({ title: this.titleValue, url: this.urlValue })
      } catch {
        // They closed the share menu - nothing to do.
      }
      return
    }

    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.doneTarget.hidden = false
      setTimeout(() => { this.doneTarget.hidden = true }, 2500)
    } catch {
      window.prompt("Copy this link:", this.urlValue)
    }
  }
}
