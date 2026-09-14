require "rails_helper"

RSpec.describe Photo, type: :model do
  let(:event) { Event.create!(name: "Wedding", slug: "wedding") }
  subject(:photo) do
    described_class.new(event: event).tap do |photo|
      photo.file.attach(
        io: StringIO.new("photo content"),
        filename: "photo.jpg",
        content_type: "image/jpeg",
        identify: false
      )
    end
  end

  it "requires an event" do
    photo.event = nil

    expect(photo).not_to be_valid
    expect(photo.errors.of_kind?(:event, :blank)).to be true
  end

  it "belongs to its event" do
    photo.save!

    expect(photo.reload.event).to eq(event)
    expect(event.photos).to contain_exactly(photo)
  end

  it "defaults to pending" do
    photo.save!

    expect(photo.reload).to be_pending
  end

  { pending: 0, uploaded: 1, failed: 2 }.each do |status, value|
    it "persists the #{status} status as #{value}" do
      photo.status = status
      photo.save!

      expect(photo.reload.public_send("#{status}?")).to be true
      expect(photo.status_before_type_cast).to eq(value)
      expect(described_class.public_send(status)).to include(photo)
    end
  end

  it "rejects unknown statuses" do
    expect { photo.status = :unknown }.to raise_error(ArgumentError)
  end

  it "persists an attached file" do
    photo.save!

    expect(photo.reload.file).to be_attached
    expect(photo.file.download).to eq("photo content")
    expect(photo.file.filename.to_s).to eq("photo.jpg")
  end

  it "allows an absent guest name" do
    photo.guest_name = nil

    expect(photo).to be_valid
  end

  it "requires a file" do
    photo.file.detach

    expect(photo).not_to be_valid
    expect(photo.errors.of_kind?(:file, :blank)).to be true
  end

  %w[image/jpeg image/png image/webp image/heic image/heif].each do |content_type|
    it "accepts #{content_type}" do
      photo.file.blob.content_type = content_type

      expect(photo).to be_valid
    end
  end

  %w[image/svg+xml application/pdf application/zip image/gif application/octet-stream].each do |content_type|
    it "rejects #{content_type}" do
      photo.file.blob.content_type = content_type

      expect(photo).not_to be_valid
      expect(photo.errors[:file]).to include("deve ser uma imagem JPEG, PNG, WebP, HEIC ou HEIF.")
    end
  end

  it "accepts a file of exactly 20 MB" do
    photo.file.blob.byte_size = 20.megabytes

    expect(photo).to be_valid
  end

  it "rejects a file larger than 20 MB" do
    photo.file.blob.byte_size = 20.megabytes + 1

    expect(photo).not_to be_valid
    expect(photo.errors[:file]).to include("deve ter no máximo 20 MB.")
  end
end
