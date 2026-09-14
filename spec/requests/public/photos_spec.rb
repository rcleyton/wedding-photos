require "rails_helper"

RSpec.describe "Public photo uploads", type: :request do
  let!(:event) do
    Event.create!(
      name: "Casamento de Ana",
      slug: "ana"
    )
  end

  let(:file) do
    fixture_file_upload(
      "photo.jpg",
      "image/jpeg"
    )
  end

  after do
    event.photos.each { |photo| photo.file.purge }
  end

  it "creates an attached photo and redirects to the public event" do
    expect do
      post public_event_photos_path(event.public_token),
           params: {
             photo: {
               guest_name: "Maria",
               files: [ file ]
             }
           }
    end.to change(Photo, :count).by(1)

    photo = event.photos.sole

    expect(photo.guest_name).to eq("Maria")
    expect(photo).to be_pending
    expect(photo.file).to be_attached

    expect(photo.file.download).to eq(
      File.binread(
        Rails.root.join("spec/fixtures/files/photo.jpg")
      )
    )

    expect(response).to have_http_status(:see_other)

    expect(response).to redirect_to(
      public_event_path(event.public_token)
    )

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "1 foto enviada com sucesso!"
    )
  end

  it "rejects a submission without files and renders the form with errors" do
    expect do
      post public_event_photos_path(event.public_token),
           params: {
             photo: {
               guest_name: "Maria"
             }
           }
    end.not_to change(Photo, :count)

    expect(response).to have_http_status(422)

    document = Nokogiri::HTML(response.body)

    expect(
      document.at_css('[role="alert"]').text
    ).to include(
      "Selecione pelo menos uma foto."
    )

    expect(
      document.at_css(
        'input[name="photo[guest_name]"]'
      )["value"]
    ).to eq("Maria")

    expect(
      document.at_css("form")["action"]
    ).to eq(
      public_event_photos_path(event.public_token)
    )

    expect(response.body).to include(event.name)
  end

  it "ignores submitted status and event IDs" do
    other_event = Event.create!(
      name: "Outro casamento",
      slug: "outro"
    )

    post public_event_photos_path(event.public_token),
         params: {
           photo: {
             files: [
               file,
               fixture_file_upload(
                 "photo.jpg",
                 "image/jpeg"
               )
             ],
             status: "uploaded",
             event_id: other_event.id
           }
         }

    expect(response).to have_http_status(:see_other)

    expect(event.photos.count).to eq(2)
    expect(event.photos).to all(be_pending)

    expect(other_event.photos).to be_empty
  end

  it "returns 404 and creates no photo for an invalid public token" do
    expect do
      post public_event_photos_path("invalid-token"),
           params: {
             photo: {
               files: [ file ]
             }
           }
    end.not_to change(Photo, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "creates one pending Photo per file with the same guest name" do
    second_file = fixture_file_upload(
      "photo.jpg",
      "image/jpeg"
    )

    expect do
      post public_event_photos_path(event.public_token),
           params: {
             photo: {
               guest_name: "Maria",
               files: [
                 "",
                 file,
                 second_file
               ]
             }
           }
    end.to change(Photo, :count).by(2)
      .and change(ActiveStorage::Attachment, :count).by(2)
      .and change(ActiveStorage::Blob, :count).by(2)

    expect(
      event.photos.map(&:guest_name)
    ).to eq(
      [ "Maria", "Maria" ]
    )

    expect(event.photos).to all(be_pending)

    event.photos.each do |photo|
      expect(photo.file).to be_attached

      expect(photo.file.download).to eq(
        File.binread(
          Rails.root.join(
            "spec/fixtures/files/photo.jpg"
          )
        )
      )
    end

    expect(response).to redirect_to(
      public_event_path(event.public_token)
    )

    follow_redirect!

    expect(response.body).to include(
      "2 fotos enviadas com sucesso!"
    )
  end

  it "allows an absent guest name" do
    post public_event_photos_path(event.public_token),
         params: {
           photo: {
             files: [ file ]
           }
         }

    expect(response).to have_http_status(:see_other)

    expect(
      event.photos.sole.guest_name
    ).to be_nil
  end

  [
    {},
    { photo: { files: [ "" ] } },
    { photo: { files: [] } }
  ].each do |parameters|
    it "rejects an empty selection #{parameters.inspect}" do
      expect do
        post public_event_photos_path(event.public_token),
             params: parameters
      end.not_to change(Photo, :count)

      expect(response).to have_http_status(422)

      expect(response.body).to include(
        "Selecione pelo menos uma foto."
      )
    end
  end

  it "rolls back photos, attachments and blobs when the second photo cannot be saved" do
    initial_count = Photo.count
    saves = 0

    allow_any_instance_of(Photo)
      .to receive(:save!)
      .and_wrap_original do |original, *args, **kwargs|
        saves += 1

        if saves == 2
          expect(Photo.count).to eq(initial_count + 1)

          original.receiver.errors.add(
            :file,
            "não pôde ser salvo"
          )

          raise ActiveRecord::RecordInvalid,
                original.receiver
        end

        original.call(*args, **kwargs)
      end

    expect do
      post public_event_photos_path(event.public_token),
           params: {
             photo: {
               guest_name: "Maria",
               files: [
                 file,
                 fixture_file_upload(
                   "photo.jpg",
                   "image/jpeg"
                 )
               ]
             }
           }
    end.to change(Photo, :count).by(0)
      .and change(ActiveStorage::Attachment, :count).by(0)
      .and change(ActiveStorage::Blob, :count).by(0)

    expect(saves).to eq(2)

    expect(response).to have_http_status(422)

    document = Nokogiri::HTML(response.body)

    expect(
      document.at_css('[role="alert"]').text
    ).to include(
      "Nenhuma foto foi enviada",
      "não pôde ser salvo"
    )

    expect(
      document.at_css(
        'input[name="photo[guest_name]"]'
      )["value"]
    ).to eq("Maria")
  end
end
