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

  it "belongs to its event and allows an absent guest name and file" do
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
    photo.file.attach(io: StringIO.new("photo content"), filename: "photo.jpg", content_type: "image/jpeg", identify: false)
    photo.save!

    expect(photo.reload.file).to be_attached
    expect(photo.file.download).to eq("photo content")
    expect(photo.file.filename.to_s).to eq("photo.jpg")
  ensure
    photo.file.purge if photo.file.attached?
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
end
