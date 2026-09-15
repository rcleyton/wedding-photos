import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["files", "counter", "error", "previews", "button"]

  connect() {
    this.urls = []
    this.sending = false
    this.select()
  }

  disconnect() {
    this.cleanup()
  }

  cleanup() {
    this.urls?.forEach(url => URL.revokeObjectURL(url))
    this.urls = []
  }

  select() {
    this.cleanup()
    this.previewsTarget.replaceChildren()
    const files = Array.from(this.filesTarget.files)
    this.counterTarget.textContent = `${files.length} ${files.length === 1 ? "foto selecionada" : "fotos selecionadas"}`
    this.overLimit = files.length > 20
    this.errorTarget.hidden = !this.overLimit
    this.errorTarget.textContent = this.overLimit ? "Selecione no máximo 20 fotos por envio." : ""
    this.filesTarget.setCustomValidity(this.overLimit ? this.errorTarget.textContent : "")
    this.buttonTarget.disabled = this.sending || this.overLimit

    // Avoid allocating previews for an oversized selection.
    if (this.overLimit) return

    files.forEach(file => {
      const item = document.createElement("div")
      item.className = "min-w-0 space-y-1"
      if (["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
        const url = URL.createObjectURL(file)
        this.urls.push(url)
        const img = document.createElement("img")
        img.src = url
        img.alt = `Prévia de ${file.name}`
        img.className = "w-full h-24 object-cover rounded"
        img.addEventListener("error", () => img.remove(), { once: true })
        item.append(img)
      }
      const name = document.createElement("p")
      name.className = "text-sm break-all"
      name.textContent = file.name
      item.append(name)
      this.previewsTarget.append(item)
    })
  }

  submit(event) {
    if (this.sending || this.filesTarget.files.length > 20) {
      event.preventDefault()
      return
    }
    this.sending = true
    this.buttonTarget.disabled = true
    this.buttonTarget.value = "Enviando..."
  }

  finish() {
    this.sending = false
    this.buttonTarget.value = "Enviar fotos"
    this.buttonTarget.disabled = this.overLimit
  }

  reset() {
    this.filesTarget.value = ""
    this.finish()
    this.select()
  }
}
