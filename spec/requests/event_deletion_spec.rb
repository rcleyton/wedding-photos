require "rails_helper"

RSpec.describe "Administrative event deletion", type: :request do
  include ActiveJob::TestHelper

  let!(:event) { Event.create!(name: "Wedding", slug: "wedding") }

  def create_photo(event)
    event.photos.create!(file: {
      io: StringIO.new("photo content"), filename: "photo.jpg", content_type: "image/jpeg", identify: false
    })
  end

  after do
    Photo.all.each { |photo| photo.file.purge }
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "prevents deletion without authentication" do
    photo = create_photo(event)
    expect { delete event_path(event) }.not_to change(Event, :count)
    expect(response).to redirect_to(new_session_path)
    expect(photo.reload.file).to be_attached
  end

  context "when authenticated" do
    before do
      user = User.create!(email_address: "admin@example.com", password: "test-password")
      post session_path, params: { email_address: user.email_address, password: "test-password" }
    end

    it "destroys the event and its photos and purges exclusive blobs through the native job" do
      photos = Array.new(2) { create_photo(event) }
      blobs = photos.map { |photo| photo.file.blob }
      other_event = Event.create!(name: "Other", slug: "other")
      other_photo = create_photo(other_event)

      expect do
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { delete event_path(event) }
      end.to change(Event, :count).by(-1)
        .and change(Photo, :count).by(-2)
        .and change(ActiveStorage::Attachment, :count).by(-2)
        .and change(ActiveStorage::Blob, :count).by(-2)

      blobs.each do |blob|
        expect(blob.service.exist?(blob.key)).to be false
      end
      expect(Photo.where(id: photos.map(&:id))).to be_empty
      expect(other_event.reload).to be_persisted
      expect(other_photo.reload.file.download).to eq("photo content")
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Evento excluído com sucesso!")
    end

    it "preserves a blob still attached to another event's photo" do
      photo = create_photo(event)
      blob = photo.file.blob
      other_event = Event.create!(name: "Other", slug: "other")
      other_photo = other_event.photos.create!(file: blob)

      expect do
        perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { delete event_path(event) }
      end.to change(Photo, :count).by(-1)
        .and change(ActiveStorage::Attachment, :count).by(-1)
        .and change(ActiveStorage::Blob, :count).by(0)

      expect(other_photo.reload.file.blob).to eq(blob)
      expect(other_photo.file.download).to eq("photo content")
    end

    it "shows a DELETE button with explicit Turbo confirmation on the event dashboard" do
      get event_path(event)
      form = Nokogiri::HTML(response.body).css("form").find { |element| element["action"] == event_path(event) }
      expect(form.at_css("button").text).to eq("Excluir evento")
      expect(form.at_css('input[name="_method"]')["value"]).to eq("delete")
      expect(form["data-turbo-confirm"]).to eq("Tem certeza? Todas as fotos deste evento também serão excluídas.")
    end

    it "returns 404 for a missing event" do
      delete event_path(id: "missing")
      expect(response).to have_http_status(:not_found)
    end
  end
end
