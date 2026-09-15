require "rails_helper"

RSpec.describe "Administrative home", type: :request do
  def sign_in
    user = User.create!(email_address: "admin@example.com", password: "test-password")
    post session_path, params: { email_address: user.email_address, password: "test-password" }
  end

  it "redirects unauthenticated visitors to login" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the empty state and a logout button" do
    sign_in
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nenhum evento cadastrado.")
    document = Nokogiri::HTML(response.body)
    logout = document.css("form").find { |form| form["action"] == session_path }
    expect(logout.at_css('input[name="_method"]')["value"]).to eq("delete")
    expect(logout.at_css("button").text).to eq("Sair")
  end

  it "lists events newest first with photo counts, optional dates and event links" do
    older = Event.create!(name: "Evento antigo", slug: "antigo", created_at: 2.days.ago, event_date: Date.new(2026, 9, 15))
    newer = Event.create!(name: "Evento recente", slug: "recente", created_at: 1.day.ago)
    2.times do
      older.photos.create!(file: {
        io: StringIO.new("photo content"), filename: "photo.jpg", content_type: "image/jpeg", identify: false
      })
    end
    sign_in

    get root_path

    expect(response).to have_http_status(:ok)
    cards = Nokogiri::HTML(response.body).css("article")
    expect(cards.map { |card| card.at_css("h2").text }).to eq([ newer.name, older.name ])
    expect(cards.first.text).to include("Fotos recebidas: 0")
    expect(cards.first.text).not_to include("Data:")
    expect(cards.last.text).to include("Fotos recebidas: 2", "Data: 15/09/2026")
    [ newer, older ].zip(cards).each do |event, card|
      expect(card.css("a").map { |link| link["href"] }).to contain_exactly(event_path(event), qr_code_event_path(event))
    end
  ensure
    older&.photos&.each { |photo| photo.file.purge }
  end
end
