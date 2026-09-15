require "rails_helper"

RSpec.describe "Administrative event editing", type: :request do
  let!(:event) { Event.create!(name: "Original", slug: "original", event_date: Date.new(2026, 10, 15)) }
  let(:attributes) { { name: "Atualizado", slug: "atualizado", event_date: "2026-11-20" } }

  it "requires authentication to edit" do
    get edit_event_path(event)
    expect(response).to redirect_to(new_session_path)
  end

  %i[patch put].each do |verb|
    it "prevents unauthenticated #{verb} updates" do
      expect do
        public_send(verb, event_path(event), params: { event: attributes })
      end.not_to change { event.reload.attributes }
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when authenticated" do
    before do
      user = User.create!(email_address: "admin@example.com", password: "test-password")
      post session_path, params: { email_address: user.email_address, password: "test-password" }
    end

    it "shows a populated edit form" do
      get edit_event_path(event)
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      form = document.css("form").find { |element| element["action"] == event_path(event) }
      expect(form.at_css('input[name="_method"]')["value"]).to eq("patch")
      expect(form.at_css('input[name="event[name]"]')["value"]).to eq(event.name)
      expect(form.at_css('input[name="event[slug]"]')["value"]).to eq(event.slug)
      expect(form.at_css('input[name="event[event_date]"]')["value"]).to eq("2026-10-15")
      expect(form.at_css('input[type="submit"]')["value"]).to eq("Atualizar evento")
    end

    %i[patch put].each do |verb|
      it "updates permitted attributes via #{verb} without changing the token" do
        token = event.public_token
        public_send(verb, event_path(event), params: { event: attributes })
        expect(response).to redirect_to(event_path(event))
        event.reload
        expect(event.name).to eq("Atualizado")
        expect(event.slug).to eq("atualizado")
        expect(event.event_date).to eq(Date.new(2026, 11, 20))
        expect(event.public_token).to eq(token)
        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Evento atualizado com sucesso!")
      end
    end

    it "ignores protected parameters and preserves the public URL and QR code" do
      token = event.public_token
      original_id = event.id
      original_created_at = event.created_at
      patch event_path(event), params: { event: attributes.merge(
        public_token: "injected", id: -123, created_at: "2000-01-01", updated_at: "2000-01-01"
      ) }
      expect(response).to redirect_to(event_path(event))
      event.reload
      expect(event.public_token).to eq(token)
      expect(event.id).to eq(original_id)
      expect(event.created_at).to eq(original_created_at)
      expect(event.updated_at.year).not_to eq(2000)

      expected_url = public_event_url(
        public_token: token,
        host: "www.example.com",
        protocol: "http"
      )
      expect(RQRCode::QRCode).to receive(:new).with(expected_url).and_call_original
      get qr_code_event_path(event)
      expect(response).to have_http_status(:ok)

      delete session_path
      get public_event_path(token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Atualizado")
    end

    it "rejects invalid updates without changing the saved event" do
      expect do
        patch event_path(event), params: { event: attributes.merge(name: "", slug: "") }
      end.not_to change { event.reload.attributes }
      expect(response).to have_http_status(422)
      expect(Nokogiri::HTML(response.body).at_css('[role="alert"]').text).to include("Name", "Slug")
    end

    it "rejects duplicate slugs and keeps submitted values in the form" do
      Event.create!(name: "Outro", slug: "atualizado")
      expect do
        patch event_path(event), params: { event: attributes }
      end.not_to change { event.reload.attributes }
      expect(response).to have_http_status(422)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('[role="alert"]').text).to include("Slug has already been taken")
      attributes.each do |attribute, value|
        expect(document.at_css("input[name='event[#{attribute}]']")["value"]).to eq(value)
      end
    end

    it "links to editing from the event dashboard" do
      get event_path(event)
      link = Nokogiri::HTML(response.body).css("a").find { |element| element["href"] == edit_event_path(event) }
      expect(link.text).to eq("Editar evento")
    end

    it "returns 404 for a missing event" do
      get edit_event_path(id: "missing")
      expect(response).to have_http_status(:not_found)
      patch event_path(id: "missing"), params: { event: attributes }
      expect(response).to have_http_status(:not_found)
    end
  end
end
