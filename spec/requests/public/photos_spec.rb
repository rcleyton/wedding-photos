require "rails_helper"

RSpec.describe "Public photo uploads", type: :request do
  let!(:event) { Event.create!(name: "Casamento de Ana", slug: "ana") }
  let(:file) { fixture_file_upload("photo.svg", "image/svg+xml") }

  after do
    event.photos.each { |photo| photo.file.purge }
  end

  it "creates an attached photo and redirects to the public event" do
    expect do
      post public_event_photos_path(event.public_token), params: { photo: { guest_name: "Maria", file: file } }
    end.to change(Photo, :count).by(1)

    photo = event.photos.sole
    expect(photo.guest_name).to eq("Maria")
    expect(photo).to be_pending
    expect(photo.file).to be_attached
    expect(photo.file.download).to eq(File.binread(Rails.root.join("spec/fixtures/files/photo.svg")))
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(public_event_path(event.public_token))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Foto enviada com sucesso!")
  end

  it "rejects a photo without a file and renders the form with errors" do
    expect do
      post public_event_photos_path(event.public_token), params: { photo: { guest_name: "Maria" } }
    end.not_to change(Photo, :count)

    expect(response).to have_http_status(422)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[role="alert"]').text).to include("File")
    expect(document.at_css('input[name="photo[guest_name]"]')["value"]).to eq("Maria")
    expect(document.at_css("form")["action"]).to eq(public_event_photos_path(event.public_token))
    expect(response.body).to include(event.name)
  end

  it "ignores submitted status and event IDs" do
    other_event = Event.create!(name: "Outro casamento", slug: "outro")

    post public_event_photos_path(event.public_token), params: {
      photo: { file: file, status: "uploaded", event_id: other_event.id }
    }

    expect(response).to have_http_status(:see_other)
    expect(event.photos.sole).to be_pending
    expect(other_event.photos).to be_empty
  end

  it "returns 404 and creates no photo for an invalid public token" do
    expect do
      post public_event_photos_path("invalid-token"), params: { photo: { file: file } }
    end.not_to change(Photo, :count)

    expect(response).to have_http_status(:not_found)
  end
end
