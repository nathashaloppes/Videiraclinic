import { Controller } from "@hotwired/stimulus"

// Aplica máscara de formatação em inputs de telefone e CPF.
// Uso:
//   <input data-controller="input-mask" data-input-mask-pattern-value="phone">
//   <input data-controller="input-mask" data-input-mask-pattern-value="cpf">
//
// O valor exibido fica formatado; no submit, os dígitos crus são enviados ao servidor
// (compatível com a validação `\A\d{11}\z` do model).
export default class extends Controller {
  static values = { pattern: String }

  connect() {
    this.format()
    this.element.addEventListener("input", this.onInput)
    this.element.form?.addEventListener("formdata", this.onFormData)
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput)
    this.element.form?.removeEventListener("formdata", this.onFormData)
  }

  onInput = () => this.format()

  onFormData = (event) => {
    const name = this.element.name
    if (!name) return
    event.formData.set(name, this.digits())
  }

  format() {
    const digits = this.digits()
    this.element.value = this.patternValue === "cpf"
      ? this.formatCpf(digits)
      : this.formatPhone(digits)
  }

  digits() {
    return (this.element.value || "").replace(/\D/g, "")
  }

  formatCpf(d) {
    d = d.slice(0, 11)
    if (d.length <= 3)  return d
    if (d.length <= 6)  return `${d.slice(0,3)}.${d.slice(3)}`
    if (d.length <= 9)  return `${d.slice(0,3)}.${d.slice(3,6)}.${d.slice(6)}`
    return `${d.slice(0,3)}.${d.slice(3,6)}.${d.slice(6,9)}-${d.slice(9)}`
  }

  formatPhone(d) {
    d = d.slice(0, 11)
    if (d.length === 0)  return ""
    if (d.length <= 2)   return `(${d}`
    if (d.length <= 6)   return `(${d.slice(0,2)}) ${d.slice(2)}`
    if (d.length <= 10)  return `(${d.slice(0,2)}) ${d.slice(2,6)}-${d.slice(6)}`
    return `(${d.slice(0,2)}) ${d.slice(2,7)}-${d.slice(7)}`
  }
}
