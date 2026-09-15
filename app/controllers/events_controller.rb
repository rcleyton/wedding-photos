class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :qr_code, :edit, :update, :destroy ]

  def destroy
    @event.destroy!
    redirect_to root_path, status: :see_other, notice: "Evento excluído com sucesso!"
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to event_path(@event),
                  status: :see_other,
                  notice: "Evento atualizado com sucesso!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to event_path(@event),
                  status: :see_other,
                  notice: "Evento criado com sucesso!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @photos = @event.photos
                    .with_attached_file
                    .order(created_at: :desc, id: :desc)
                    .load
  end

  def qr_code
    @public_url = public_event_url(
      public_token: @event.public_token
    )

    @qr_code = RQRCode::QRCode.new(@public_url)
  end

  private

  def event_params
    params.require(:event).permit(
      :name,
      :slug,
      :event_date
    )
  end

  def set_event
    @event = Event.find(params[:id])
  end
end
