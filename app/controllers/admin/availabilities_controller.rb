class Admin::AvailabilitiesController < Admin::BaseController
  before_action :set_availability, only: [:edit, :update, :destroy]

  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @availabilities = current_clinic.availabilities
      .where(date: @date)
      .includes(:service, :dentist)
      .order(:starts_at)
    @services = current_clinic.services.active.order(:name)
    @dentists = current_clinic.users.dentist.order(:name)
  rescue Date::Error
    redirect_to admin_availabilities_path, alert: "Data inválida."
  end

  def new
    @availability = Availability.new(date: params[:date], clinic: current_clinic)
    @services = current_clinic.services.active.order(:name)
    @dentists = current_clinic.users.dentist.order(:name)
  end

  def create
    @availability = current_clinic.availabilities.new(availability_params)

    if @availability.save
      redirect_to admin_availabilities_path(date: @availability.date),
        notice: "Horário criado com sucesso."
    else
      @services = current_clinic.services.active.order(:name)
      @dentists = current_clinic.users.dentist.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @services = current_clinic.services.active.order(:name)
    @dentists = current_clinic.users.dentist.order(:name)
  end

  def update
    if @availability.update(availability_params)
      redirect_to admin_availabilities_path(date: @availability.date),
        notice: "Horário atualizado."
    else
      @services = current_clinic.services.active.order(:name)
      @dentists = current_clinic.users.dentist.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @availability.booked?
      redirect_to admin_availabilities_path(date: @availability.date),
        alert: "Não é possível excluir um horário já reservado."
    else
      @availability.destroy!
      redirect_to admin_availabilities_path(date: @availability.date),
        notice: "Horário removido."
    end
  end

  private

  def set_availability
    @availability = current_clinic.availabilities.find(params[:id])
  end

  def availability_params
    params.require(:availability).permit(:service_id, :dentist_id, :date, :starts_at, :ends_at, :status)
  end

  def current_clinic
    current_user.clinic
  end
end
