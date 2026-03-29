import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "step", "nextBtn", "backBtn", "closeBtn", "stepLabel", "dot"]
  static values = { completeUrl: String, currentStep: { type: Number, default: 0 } }

  connect() {
    if (this.element.dataset.showOnboarding === "true") {
      this.showModal()
    }
    this.updateUI()
  }

  showModal() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  hideModal() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  next() {
    if (this.currentStepValue < this.stepTargets.length - 1) {
      this.currentStepValue++
      this.updateUI()
    }
  }

  back() {
    if (this.currentStepValue > 0) {
      this.currentStepValue--
      this.updateUI()
    }
  }

  close() {
    this.hideModal()
    this.markComplete()
  }

  skip() {
    this.hideModal()
    this.markComplete()
  }

  markComplete() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.completeUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Content-Type": "application/json"
      }
    })
  }

  updateUI() {
    const total = this.stepTargets.length
    const current = this.currentStepValue

    this.stepTargets.forEach((step, i) => {
      step.classList.toggle("hidden", i !== current)
    })

    this.stepLabelTarget.textContent = `${current + 1} / ${total}`
    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-amber-700", i === current)
      dot.classList.toggle("bg-gray-200", i !== current)
    })

    this.backBtnTarget.classList.toggle("invisible", current === 0)

    const isLast = current === total - 1
    this.nextBtnTarget.classList.toggle("hidden", isLast)
    this.closeBtnTarget.classList.toggle("hidden", !isLast)
  }
}
