class DashboardController < ApplicationController
  def index
    @events = Event.order(created_at: :desc, id: :desc)
    @photo_counts = Photo.group(:event_id).count
  end
end
