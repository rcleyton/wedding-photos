require "rails_helper"

RSpec.describe "Administrative event creation", type: :request do
  let(:attributes) { { name: "Casamento de Ana", slug: "ana", event_date: "2026-10-15" } }

  it "requires authentication to open the form" do
    get new_event_path
    expect(response).to redirect_to(new_session_path)
  end

  it "prevents unauthenticated creation" do
    expect { post events_path, params: { event: attributes } }.not_to change(Event, :count)
    expect(response).to redirect_to(new_session_path)
  end

  context "when authenticated" do
    before do
      user = User.create!(email_address: "admin@example.com", password: "test-password")
      post session_path, params: { email_address: user.email_address, password: "test-password" }
    end

    it "shows the creation form" do
      get new_event_path
      expect(response).to have_http_status(:ok)
      form = Nokogiri::HTML(response.body).css("form").find { |element| element["action"] == events_path }
      expect(form["method"]).to eq("post")
      %w[name slug event_date].each do |attribute|
        expect(form.at_css("input[name='event[#{attribute}]']")).to be_present
      end
      expect(form.at_css('input[name="event[public_token]"]')).to be_nil
    end

    it "creates the event with a generated token and displays success after redirecting" do
      expect { post events_path, params: { event: attributes } }.to change(Event, :count).by(1)
      event = Event.order(:id).last
      expect(event.public_token).to be_present
      expect(event.public_token).not_to eq("client-token")
    end

    it "ignores client-supplied tokens, IDs and timestamps" do
      post events_path, params: { event: attributes.merge(
        public_token: "client-token", id: -123, created_at: "2000-01-01", updated_at: "2000-01-01"
      ) }
      event = Event.find_by!(slug: "ana")
      expect(event.public_token).not_to eq("client-token")
      expect(event.id).not_to eq(-123)
      expect(event.created_at.year).not_to eq(2000)
      expect(event.updated_at.year).not_to eq(2000)
    end

    it "rejects invalid input and displays validation errors" do
      expect do
        post events_path, params: { event: attributes.merge(name: "", slug: "") }
      end.not_to change(Event, :count)
      expect(response).to have_http_status(422)
      alert = Nokogiri::HTML(response.body).at_css('[role="alert"]')
      expect(alert.text).to include("Name", "Slug")
    end

    it "rejects a duplicate slug and preserves the entered values" do
      Event.create!(name: "Existing", slug: "ana")
      expect { post events_path, params: { event: attributes } }.not_to change(Event, :count)
      expect(response).to have_http_status(422)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('[role="alert"]').text).to include("Slug has already been taken")
      attributes.each do |attribute, value|
        expect(document.at_css("input[name='event[#{attribute}]']")["value"]).to eq(value)
      end
    end

    it "links to the creation form from the administrative home" do
      get root_path
      link = Nokogiri::HTML(response.body).css("a").find { |element| element["href"] == new_event_path }
      expect(link.text).to eq("Novo evento")
    end
  end
end
