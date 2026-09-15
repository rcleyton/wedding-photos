require "rails_helper"

RSpec.describe "Administrative photo deletion", type: :request do
  include ActiveJob::TestHelper

  let!(:event) { Event.create!(name: "Wedding", slug: "wedding") }
  let!(:photo) { create_photo(event) }

  def create_photo(event)
    event.photos.create!(file: {
      io: StringIO.new("photo content"), filename: "photo.jpg", content_type: "image/jpeg", identify: false
    })
  end

  after do
    Photo.all.each { |record| record.file.purge }
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "prevents deletion without authentication" do
    expect { delete event_photo_path(event, photo) }.not_to change(Photo, :count)
    expect(response).to redirect_to(new_session_path)
    expect(photo.reload.file.download).to eq("photo content")
  end

  context "when authenticated" do
    before do
      user = User.create!(email_address: "admin@example.com", password: "test-password")
      post session_path, params: { email_address: user.email_address, password: "test-password" }
    end

    it "deletes only the selected photo and purges its exclusive blob and file" do
      remaining = create_photo(event)
      blob = photo.file.blob
      expect(blob.service.exist?(blob.key)).to be true

      expect do
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { delete event_photo_path(event, photo) }
      end.to change(Photo, :count).by(-1)
        .and change(ActiveStorage::Attachment, :count).by(-1)
        .and change(ActiveStorage::Blob, :count).by(-1)
        .and change(Event, :count).by(0)

      expect(Photo.exists?(photo.id)).to be false
      expect(blob.service.exist?(blob.key)).to be false
      expect(remaining.reload.file.download).to eq("photo content")
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(event_path(event))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Foto excluída com sucesso!")
    end

    it "preserves a blob and file still used by another photo" do
      blob = photo.file.blob
      other_event = Event.create!(name: "Other", slug: "other")
      other_photo = other_event.photos.create!(file: blob)

      expect do
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { delete event_photo_path(event, photo) }
      end.to change(Photo, :count).by(-1)
        .and change(ActiveStorage::Attachment, :count).by(-1)
        .and change(ActiveStorage::Blob, :count).by(0)

      expect(other_photo.reload.file.blob).to eq(blob)
      expect(other_photo.file.download).to eq("photo content")
    end

    it "returns 404 when the photo belongs to a different event" do
      other_event = Event.create!(name: "Other", slug: "other")
      other_photo = create_photo(other_event)

      expect do
        delete event_photo_path(event, other_photo)
      end.to change(Photo, :count).by(0)
        .and change(ActiveStorage::Attachment, :count).by(0)
        .and change(ActiveStorage::Blob, :count).by(0)

      expect(response).to have_http_status(:not_found)
      expect(other_photo.reload.file.download).to eq("photo content")
      expect(photo.reload.file).to be_attached
    end

    it "returns 404 for a missing photo" do
      delete event_photo_path(event, id: "missing")
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a missing event" do
      delete event_photo_path(event_id: "missing", id: photo.id)
      expect(response).to have_http_status(:not_found)
      expect(photo.reload).to be_persisted
    end

    it "shows a DELETE button and explicit Turbo confirmation for each photo" do
      second = create_photo(event)
      get event_path(event)
      document = Nokogiri::HTML(response.body)

      [ photo, second ].each do |record|
        form = document.css("article form").find { |element| element["action"] == event_photo_path(event, record) }
        expect(form.at_css("button").text).to eq("Excluir foto")
        expect(form.at_css('input[name="_method"]')["value"]).to eq("delete")
        expect(form["data-turbo-confirm"]).to eq("Tem certeza que deseja excluir esta foto?")
      end
    end
  end
end
