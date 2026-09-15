Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resources :passwords, param: :token
  resources :events, only: [ :new, :create, :show, :edit, :update ] do
    get :qr_code, on: :member
  end

  namespace :public, path: "e" do
    get ":public_token", to: "events#show", as: :event
    post ":public_token/photos", to: "photos#create", as: :event_photos
  end
end
