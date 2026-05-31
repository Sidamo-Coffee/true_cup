import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submit() {
    if (!this.hasSubmitTarget) return
    const btn = this.submitTarget
    btn.disabled = true
    btn.value = "送信中..."
    btn.classList.add("opacity-70", "cursor-not-allowed")
  }
}
