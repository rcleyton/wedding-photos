module Public
  class EventsController < ApplicationController
    allow_unauthenticated_access

    def show
      @event = Event.find_by!(public_token: params[:public_token])
      @photo = @event.photos.new
    end
  end
end
