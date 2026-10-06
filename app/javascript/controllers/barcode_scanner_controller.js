import { Controller } from "@hotwired/stimulus"

// "Scan barcode": reads a book's ISBN barcode with the device camera, using the
// browser's built-in BarcodeDetector (Chrome on Android and Mac; not yet Safari
// or Firefox, where the button stays hidden and the ISBN can be typed instead).
// On success it emits "barcode-scanner:scanned" with { isbn }.
export default class extends Controller {
  static targets = [ "button", "dialog", "video", "message" ]

  connect() {
    this.buttonTarget.hidden = !("BarcodeDetector" in window && navigator.mediaDevices?.getUserMedia)
  }

  disconnect() {
    this.close()
  }

  async open() {
    this.dialogTarget.showModal()
    this.#say("Point the camera at the barcode on the back of the book.")

    try {
      const formats = await BarcodeDetector.getSupportedFormats()
      if (!formats.includes("ean_13")) throw new Error("ean_13 not supported")

      this.detector = new BarcodeDetector({ formats: [ "ean_13" ] })
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()
      this.#scan()
    } catch (error) {
      this.#say(error.name === "NotAllowedError"
        ? "Camera access was blocked. Allow the camera for this site, or type the ISBN instead."
        : "Couldn't start the camera on this device. Type the ISBN instead.")
    }
  }

  // Also runs when the dialog closes any other way (Escape key, Cancel button).
  close() {
    clearTimeout(this.timer)
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Look at the camera picture a few times a second until an ISBN shows up.
  async #scan() {
    if (!this.stream) return

    try {
      const codes = await this.detector.detect(this.videoTarget)
      // Book barcodes are EAN-13 numbers starting 978 or 979 (= the ISBN-13).
      const isbn = codes.map((code) => code.rawValue).find((value) => /^97[89]\d{10}$/.test(value))
      if (isbn) {
        this.close()
        this.dispatch("scanned", { detail: { isbn } })
        return
      }
    } catch {
      // A frame that couldn't be read - just try the next one.
    }
    this.timer = setTimeout(() => this.#scan(), 250)
  }

  #say(message) {
    this.messageTarget.textContent = message
  }
}
