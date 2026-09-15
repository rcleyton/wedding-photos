require "rails_helper"

RSpec.describe "Event dashboard", type: :request do
  let!(:event) { Event.create!(name: "Casamento de Ana", slug: "ana", event_date: Date.new(2026, 9, 14)) }

  def create_photo(event:, filename:, guest_name: nil, created_at: Time.current, content_type: "image/jpeg")
    event.photos.create!(
      guest_name: guest_name,
      created_at: created_at,
      file: { io: StringIO.new("photo content"), filename: filename, content_type: content_type, identify: false }
    )
  end

  after do
    Photo.all.each { |photo| photo.file.purge }
  end

  it "shows event details and links to the public page and QR code" do
    get event_path(event)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("h1").text).to eq(event.name)
    expect(document.text).to include("Data: 14/09/2026", "Fotos recebidas: 0")
    links = document.css("a").map { |link| link["href"] }
    expect(links).to include(public_event_path(event.public_token), qr_code_event_path(event))
  end

  it "shows an empty state and omits an absent event date" do
    event.update!(event_date: nil)

    get event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nenhuma foto foi enviada ainda.")
    expect(response.body).not_to include("Data:")
  end

  it "shows only this event's photos, newest first, with metadata and attachment links" do
    older = create_photo(event: event, filename: "older.jpg", guest_name: "Maria", created_at: Time.zone.local(2026, 9, 14, 18, 30))
    newer = create_photo(event: event, filename: "newer.jpg", guest_name: " ", created_at: Time.zone.local(2026, 9, 14, 20, 30))
    other_event = Event.create!(name: "Outro evento", slug: "outro")
    create_photo(event: other_event, filename: "other.jpg", guest_name: "Outro convidado")

    get event_path(event)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.text).to include("Fotos recebidas: 2")
    cards = document.css("article")
    expect(cards.size).to eq(2)
    expect(cards.map { |card| card.at_css("h2").text }).to eq([ "Convidado", "Maria" ])
    [ newer, older ].zip(cards).each do |photo, card|
      expect(card.text).to include(photo.file.filename.to_s, "pending", "13 Bytes", photo.created_at.strftime("%d/%m/%Y %H:%M"))
      expect(card.at_css("img")["src"]).to include(rails_blob_path(photo.file))
      expect(card.at_css("a")["href"]).to eq(rails_blob_path(photo.file, disposition: "attachment"))
    end
    expect(document.text).not_to include("other.jpg", "Outro convidado")
  end

  it "offers a download for HEIC without generating a variant" do
    photo = create_photo(event: event, filename: "phone.heic", content_type: "image/heic")

    get event_path(event)

    expect(response).to have_http_status(:ok)
    card = Nokogiri::HTML(response.body).at_css("article")
    expect(card.at_css("img")).to be_nil
    expect(card.text).to include("Prévia indisponível", "phone.heic")
    expect(card.at_css("a")["href"]).to eq(rails_blob_path(photo.file, disposition: "attachment"))
  end

  it "returns 404 for a missing event" do
    get event_path(id: "missing")

    expect(response).to have_http_status(:not_found)
  end
end
