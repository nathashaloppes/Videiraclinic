import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "toggle"]

  toggle() {
    const open = !this.listTarget.classList.contains("hidden")
    this.listTarget.classList.toggle("hidden", open)
    this.toggleTarget.textContent = open ? "Ver selecionados ↓" : "Fechar ↑"
  }

  // Mantém drawer aberto após Turbo Stream update
  connect() {
    if (this.element.dataset.cartDrawerOpen === "true") {
      this.listTarget.classList.remove("hidden")
      this.toggleTarget.textContent = "Fechar ↑"
    }
  }

  open() {
    this.element.dataset.cartDrawerOpen = "true"
    this.listTarget.classList.remove("hidden")
    this.toggleTarget.textContent = "Fechar ↑"
  }
}
