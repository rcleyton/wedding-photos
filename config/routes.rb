Rails.application.routes.draw do
  namespace :public, path: "e" do
    get ":public_token", to: "events#show", as: :event
    post ":public_token/photos", to: "photos#create", as: :event_photos
  end
end
