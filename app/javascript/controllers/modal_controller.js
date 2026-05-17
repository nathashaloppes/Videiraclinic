import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    // Support opening a shared dialog by ID (data-modal-dialog="some-id")
    const dialogId = event.currentTarget.dataset.modalDialog
    if (dialogId) {
      document.getElementById(dialogId)?.showModal()
    } else {
      this.dialogTarget.showModal()
    }
  }

  close() {
    this.dialogTarget.close()
  }

  closeById(event) {
    const dialogId = event.currentTarget.dataset.modalDialog
    if (dialogId) {
      document.getElementById(dialogId)?.close()
    } else {
      this.dialogTarget.close()
    }
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) {
      event.currentTarget.close()
    }
  }
}
