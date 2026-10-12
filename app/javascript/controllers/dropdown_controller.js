import { Controller } from "@hotwired/stimulus"

// A <details> menu (the account menu on phones) that closes when you tap
// anywhere outside it or press Escape, like a normal app menu.
//
//   <details data-controller="dropdown"
//            data-action="click@window->dropdown#closeOutside keydown.esc@window->dropdown#close">
export default class extends Controller {
  closeOutside(event) {
    if (this.element.open && !this.element.contains(event.target)) this.close()
  }

  close() {
    this.element.open = false
  }
}
