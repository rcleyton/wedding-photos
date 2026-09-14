require "rails_helper"

RSpec.describe "Event QR codes", type: :request do
  let!(:event) { Event.create!(name: "Casamento de Ana", slug: "ana") }

  it "shows the event name, QR code and absolute public URL" do
    host! "localhost:3000"
    public_url = public_event_url(public_token: event.public_token, host: "localhost", port: 3000, protocol: "http")
    expect(RQRCode::QRCode).to receive(:new).with(public_url).and_call_original

    get qr_code_event_path(event)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("h1").text).to eq(event.name)
    expect(document.at_css('[role="img"] svg')).to be_present
    link = document.at_css("a")
    expect(link["href"]).to eq(public_url)
    expect(link.text).to eq(public_url)
    expect(response.body).to include("Convidados podem escanear este QR Code para enviar fotos do evento.")
  end

  it "encodes only the public URL with the request HTTPS host" do
    host! "photos.example.com"
    https!
    public_url = public_event_url(public_token: event.public_token, host: "photos.example.com", protocol: "https")
    expect(RQRCode::QRCode).to receive(:new).with(public_url).and_call_original

    get qr_code_event_path(event)

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css("a")["href"]).to eq(public_url)
  end

  it "returns 404 for a missing event without generating a QR code" do
    expect(RQRCode::QRCode).not_to receive(:new)

    get qr_code_event_path(id: "missing")

    expect(response).to have_http_status(:not_found)
  end
end
