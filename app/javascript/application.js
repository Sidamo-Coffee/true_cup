// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import Chartkick from "chartkick"
import "chartkick/chart.js"

document.addEventListener("turbo:load", () => {
  setTimeout(() => {
    Chartkick.eachChart((chart) => chart.redraw())
  }, 0)
})