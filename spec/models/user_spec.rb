require 'rails_helper'

RSpec.describe User, type: :model do
  it "normalizes email and authenticates a hashed password" do
    user = described_class.create!(email_address: " Admin@Example.com ", password: "test-password")

    expect(user.email_address).to eq("admin@example.com")
    expect(user.password_digest).not_to eq("test-password")
    expect(user.authenticate("test-password")).to eq(user)
    expect(user.authenticate("incorrect")).to be false
  end
end
