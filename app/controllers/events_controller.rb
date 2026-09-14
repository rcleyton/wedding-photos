class EventsController < ApplicationController
  before_action :set_event, only: :qr_code

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
