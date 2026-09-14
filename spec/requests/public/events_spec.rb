require "rails_helper"

RSpec.describe "Public events", type: :request do
  it "shows an event and a multiple photo upload form using its public token" do
    event = Event.create!(name: "Casamento de Ana", slug: "ana")

    get public_event_path(event.public_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(event.name)
    form = Nokogiri::HTML(response.body).at_css("form")
    expect(form["action"]).to eq(public_event_photos_path(event.public_token))
    expect(form["method"]).to eq("post")
    expect(form["enctype"]).to eq("multipart/form-data")
    expect(form.at_css('input[name="photo[guest_name]"]')).to be_present
    file_input = form.at_css('input[type="file"][name="photo[files][]"]')
    expect(file_input).to be_present
    expect(file_input["multiple"]).not_to be_nil
    expect(file_input["accept"]).to eq("image/jpeg,image/png,image/webp,image/heic,image/heif")
    expect(response.body).to include("Máximo de 20 fotos por envio e máximo de 20 MB por foto.")
  end

  it "returns 404 for an invalid public token" do
    get public_event_path("invalid-token")

    expect(response).to have_http_status(:not_found)
  end
end
