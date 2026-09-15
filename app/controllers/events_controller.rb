class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :qr_code ]

  def show
    @photos = @event.photos.with_attached_file.order(created_at: :desc, id: :desc).load
  end

  def qr_code
    @public_url = public_event_url(
      public_token: @event.public_token
    )

    @qr_code = RQRCode::QRCode.new(@public_url)
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end
end
