require "rails_helper"

RSpec.describe "Administrative authentication", type: :request do
  let!(:event) { Event.create!(name: "Wedding", slug: "wedding") }
  let(:user) { User.create!(email_address: "admin@example.com", password: "test-password") }

  [ :event_path, :qr_code_event_path ].each do |route|
    it "requires login and returns to #{route} after successful authentication" do
      target = public_send(route, event)
      get target
      expect(response).to redirect_to(new_session_path)

      expect do
        post session_path, params: { email_address: user.email_address, password: "test-password" }
      end.to change(Session, :count).by(1)
      expect(response).to redirect_to(target)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end

  it "provides the native login form" do
    get new_session_path
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('input[name="email_address"]')).to be_present
    expect(document.at_css('input[name="password"]')).to be_present
  end

  it "handles direct login without a root route" do
    post session_path, params: { email_address: user.email_address, password: "test-password" }
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Você está autenticado")
  end

  it "rejects invalid credentials" do
    expect do
      post session_path, params: { email_address: user.email_address, password: "wrong" }
    end.not_to change(Session, :count)
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Try another email address or password.")
    get event_path(event)
    expect(response).to redirect_to(new_session_path)
  end

  it "destroys the session on logout and denies further administrative access" do
    post session_path, params: { email_address: user.email_address, password: "test-password" }
    expect { delete session_path }.to change(Session, :count).by(-1)
    expect(response).to redirect_to(new_session_path)
    get event_path(event)
    expect(response).to redirect_to(new_session_path)
    get qr_code_event_path(event)
    expect(response).to redirect_to(new_session_path)
  end

  it "allows guests to open the public page and upload without a session" do
    get public_event_path(event.public_token)
    expect(response).to have_http_status(:ok)

    expect do
      post public_event_photos_path(event.public_token), params: {
        photo: { files: [ fixture_file_upload("photo.jpg", "image/jpeg") ] }
      }
    end.to change(Photo, :count).by(1)
    expect(response).to redirect_to(public_event_path(event.public_token))
    expect(Session.count).to eq(0)
  ensure
    event.photos.each { |photo| photo.file.purge }
  end
end
