class Admin::AvailabilitiesController < Admin::BaseController
  before_action :set_availability, only: [:edit, :update, :destroy, :toggle]

  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @availabilities = current_clinic.availabilities
      .where(date: @date)
      .order(:starts_at)
  rescue Date::Error
    redirect_to admin_availabilities_path, alert: "Data inválida."
  end

  def new
    @availability = Availability.new(date: params[:date], clinic: current_clinic)
  end

  def create
    @availability = current_clinic.availabilities.new(availability_params)

    if @availability.save
      redirect_to admin_availabilities_path(date: @availability.date),
        notice: "Turno criado com sucesso."
    else
      redirect_to admin_availabilities_path(date: availability_params[:date]),
        alert: @availability.errors.full_messages.to_sentence
    end
  end

  def edit; end

  def update
    if @availability.update(availability_params)
      redirect_to admin_availabilities_path(date: @availability.date), notice: "Turno atualizado."
    else
      redirect_to admin_availabilities_path(date: @availability.date),
                  alert: @availability.errors.full_messages.to_sentence
    end
  end

  def toggle
    if @availability.booked?
      redirect_to admin_availabilities_path(date: @availability.date),
        alert: "Turno reservado — não pode ser alterado."
    elsif @availability.available?
      @availability.update!(status: :blocked)
      redirect_to admin_availabilities_path(date: @availability.date)
    else
      @availability.update!(status: :available)
      redirect_to admin_availabilities_path(date: @availability.date)
    end
  end

  def destroy
    if @availability.booked?
      redirect_to admin_availabilities_path(date: @availability.date),
        alert: "Turno reservado — não é possível excluir."
    else
      @availability.destroy!
      redirect_to admin_availabilities_path(date: @availability.date),
        notice: "Turno removido."
    end
  end

  private

  def set_availability
    @availability = current_clinic.availabilities.find(params[:id])
  end

  def availability_params
    p = params.require(:availability).permit(:date, :starts_at, :ends_at, :status, :price)
    if p[:price].present?
      p[:price_cents] = (p.delete(:price).to_s.gsub(",", ".").to_f * 100).round
    else
      p.delete(:price)
    end
    p
  end

  def current_clinic
    current_user.clinic
  end
end
