require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { described_class.new(name: "Wedding", slug: "wedding") }

  it "is valid without an event date" do
    expect(event).to be_valid
  end

  %i[name slug public_token].each do |attribute|
    it "requires #{attribute}" do
      event.public_send("#{attribute}=", " ")

      expect(event).not_to be_valid
      expect(event.errors.of_kind?(attribute, :blank)).to be true
    end
  end

  %i[slug public_token].each do |attribute|
    it "requires a unique #{attribute}" do
      existing = described_class.create!(name: "Other wedding", slug: "other-wedding")
      event.public_send("#{attribute}=", existing.public_send(attribute))

      expect(event).not_to be_valid
      expect(event.errors.of_kind?(attribute, :taken)).to be true
    end

    it "enforces unique #{attribute} values in the database" do
      event.save!
      other = described_class.create!(name: "Other wedding", slug: "other-wedding")

      expect do
        described_class.transaction(requires_new: true) do
          other.update_column(attribute, event.public_send(attribute))
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "generates and persists a secure public token" do
    token = event.public_token

    expect(token).to match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/)
    event.save!
    expect(event.reload.public_token).to eq(token)
    expect(described_class.new.public_token).not_to eq(token)
  end

  it "keeps its token when updated" do
    event.save!
    expect { event.update!(name: "Updated wedding") }.not_to change { event.reload.public_token }
  end

  it "destroys its photos when destroyed" do
    event.save!

    photo = event.photos.new
    photo.file.attach(
      io: StringIO.new("photo content"),
      filename: "photo.jpg",
      content_type: "image/jpeg",
      identify: false
    )
    photo.save!

    expect { event.destroy! }.to change(Photo, :count).by(-1)
    expect(Photo.exists?(photo.id)).to be false
  end
end
