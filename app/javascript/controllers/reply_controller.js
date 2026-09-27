import { Controller } from "@hotwired/stimulus"

// Opens and closes the reply form inside one comment thread.
// Connected in the view with data-controller="reply".
export default class extends Controller {
  static targets = [ "form", "input" ]

  // data-action="reply#open"; data-reply-mention-param="Bob" starts the reply with "@Bob "
  open({ params: { mention } }) {
    this.formTarget.hidden = false

    const input = this.inputTarget
    if (mention && !input.value.includes(`@${mention}`)) {
      input.value = `@${mention} ${input.value}`
    }
    input.focus()
    input.setSelectionRange(input.value.length, input.value.length)
  }

  // data-action="reply#cancel"
  cancel() {
    this.inputTarget.value = ""
    this.formTarget.hidden = true
  }
}
