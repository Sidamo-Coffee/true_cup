import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextBtn", "backBtn", "submitBtn", "progressBar", "stepCounter"]
  static values = { current: { type: Number, default: 0 } }

  connect() {
    this.showStep(0)
  }

  next() {
    const currentStep = this.stepTargets[this.currentValue]
    const selected = currentStep.querySelector("input[type=radio]:checked")
    if (!selected) {
      currentStep.classList.add("ring-2", "ring-amber-400", "ring-offset-2")
      setTimeout(() => currentStep.classList.remove("ring-2", "ring-amber-400", "ring-offset-2"), 800)
      return
    }
    if (this.currentValue < this.stepTargets.length - 1) {
      this.currentValue++
      this.showStep(this.currentValue)
    }
  }

  back() {
    if (this.currentValue > 0) {
      this.currentValue--
      this.showStep(this.currentValue)
    }
  }

  showStep(index) {
    this.stepTargets.forEach((step, i) => {
      if (i === index) {
        step.classList.remove("hidden", "animate-slide-in")
        void step.offsetWidth
        step.classList.add("animate-slide-in")
      } else {
        step.classList.add("hidden")
      }
    })

    const total = this.stepTargets.length
    const percent = ((index + 1) / total) * 100
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent}%`
    }
    if (this.hasStepCounterTarget) {
      this.stepCounterTarget.textContent = `${index + 1} / ${total}`
    }

    const isFirst = index === 0
    const isLast = index === total - 1

    if (this.hasBackBtnTarget)   this.backBtnTarget.classList.toggle("invisible", isFirst)
    if (this.hasNextBtnTarget)   this.nextBtnTarget.style.display   = isLast ? "none" : ""
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.style.display = isLast ? ""     : "none"
  }
}
