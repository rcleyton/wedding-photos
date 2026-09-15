class PhotosController < ApplicationController
  before_action :set_event
  before_action :set_photo

  def destroy
    @photo.destroy!

    redirect_to event_path(@event),
                status: :see_other,
                notice: "Foto excluída com sucesso!"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_photo
    @photo = @event.photos.find(params[:id])
  end
end
