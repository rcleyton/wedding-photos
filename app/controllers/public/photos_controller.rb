module Public
  class PhotosController < ApplicationController
    allow_unauthenticated_access

    MAX_FILES_PER_UPLOAD = 20

    before_action :set_event

    def create
      attributes = photo_params

      @photo = @event.photos.new(
        guest_name: attributes[:guest_name]
      )

      files = Array(attributes[:files]).compact_blank

      if files.empty?
        @photo.errors.add(:base, "Selecione pelo menos uma foto.")

        return render "public/events/show",
                      status: :unprocessable_entity
      end

      if files.size > MAX_FILES_PER_UPLOAD
        @photo.errors.add(
          :base,
          "Envie no máximo #{MAX_FILES_PER_UPLOAD} fotos por vez."
        )

        return render "public/events/show",
                      status: :unprocessable_entity
      end

      Photo.transaction do
        files.each do |file|
          @event.photos.create!(
            guest_name: @photo.guest_name,
            file: file
          )
        end
      end

      redirect_to public_event_path(@event.public_token),
                  status: :see_other,
                  notice: success_message(files.size)
    rescue ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotSaved => error

      @photo.errors.add(
        :base,
        "Nenhuma foto foi enviada. Selecione os arquivos e tente novamente."
      )

      if error.record
        error.record.errors.full_messages.each do |message|
          @photo.errors.add(:base, message)
        end
      end

      render "public/events/show",
             status: :unprocessable_entity
    end

    private

    def set_event
      @event = Event.find_by!(
        public_token: params[:public_token]
      )
    end

    def photo_params
      params
        .fetch(:photo, ActionController::Parameters.new)
        .permit(:guest_name, files: [])
    end

    def success_message(count)
      if count == 1
        "1 foto enviada com sucesso!"
      else
        "#{count} fotos enviadas com sucesso!"
      end
    end
  end
end
