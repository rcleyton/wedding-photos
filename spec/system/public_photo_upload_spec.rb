require "rails_helper"

RSpec.describe "Public photo upload", type: :system do
  before do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ]
  end

  let!(:event) { Event.create!(name: "Wedding", slug: "wedding") }

  after do
    event.photos.each { |photo| photo.file.purge }
  end

  it "counts selections, previews supported images and blocks more than 20 files" do
    visit public_event_path(event.public_token)
    expect(page).to have_text("0 fotos selecionadas")
    attach_file "Fotos", Rails.root.join("spec/fixtures/files/photo.jpg")
    expect(page).to have_text("1 foto selecionada")
    expect(page).to have_css('img[alt="Prévia de photo.jpg"]')

    page.execute_script(<<~JS)
      const input = document.querySelector('input[type="file"]')
      const files = new DataTransfer()
      for (let i = 0; i < 21; i++) files.items.add(new File(['test'], `photo${i}.heic`, { type: 'image/heic' }))
      input.files = files.files
      input.dispatchEvent(new Event('change', { bubbles: true }))
    JS
    expect(page).to have_text("21 fotos selecionadas")
    expect(page).to have_text("Selecione no máximo 20 fotos por envio.")
    expect(page).to have_button("Enviar fotos", disabled: true)
    expect(Photo.count).to eq(0)

    attach_file "Fotos", Rails.root.join("spec/fixtures/files/photo.jpg")
    expect(page).to have_button("Enviar fotos", disabled: false)
    expect(page).to have_text("1 foto selecionada")
  end

  it "shows a busy button during submission and restores it after server validation errors" do
    visit public_event_path(event.public_token)
    attach_file "Fotos", Rails.root.join("spec/fixtures/files/photo.svg")
    # Observe the actual submission state before Turbo completes the request.
    page.execute_script(<<~JS)
      document.addEventListener('turbo:submit-start', () => {
        const button = document.querySelector('input[type="submit"]')
        sessionStorage.setItem('uploadBusy', JSON.stringify({ text: button.value, disabled: button.disabled }))
      }, { once: true })
    JS
    click_button "Enviar fotos"
    expect(page).to have_text("Nenhuma foto foi enviada")
    expect(page).to have_button("Enviar fotos", disabled: false)
    state = JSON.parse(page.evaluate_script("sessionStorage.getItem('uploadBusy')"))
    expect(state).to eq("text" => "Enviando...", "disabled" => true)
    expect(Photo.count).to eq(0)
    attach_file "Fotos", Rails.root.join("spec/fixtures/files/photo.jpg")
    click_button "Enviar fotos"
    expect(page).to have_text("1 foto enviada com sucesso!")
  end
end
