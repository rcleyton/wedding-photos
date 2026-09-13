module Public
  class PhotosController < ApplicationController
    def create
      @event = Event.find_by!(public_token: params[:public_token])
      @photo = @event.photos.new(photo_params)

      if @photo.save
        redirect_to public_event_path(@event.public_token), status: :see_other,
          notice: "Foto enviada com sucesso!"
      else
        render "public/events/show", status: :unprocessable_entity
      end
    end

    private
      def photo_params
        params.require(:photo).permit(:guest_name, :file)
      end
  end
end
