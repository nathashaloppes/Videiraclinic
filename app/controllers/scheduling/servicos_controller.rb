class Scheduling::ServicosController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @services = Service.active.where(clinic: Clinic.first).order(:name)
    @date     = params[:date].present? ? Date.parse(params[:date]) : Date.current
  rescue Date::Error
    @date = Date.current
  ensure
    @date ||= Date.current
  end

  def show
    @service = Service.active.find(params[:id])
    @date    = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @availabilities = @service.availabilities
      .available
      .where(date: @date.beginning_of_week..@date.end_of_week)
      .order(:date, :starts_at)
  rescue ActiveRecord::RecordNotFound
    redirect_to servicos_path, alert: "Serviço não encontrado."
  rescue Date::Error
    @date = Date.current
    retry
  end
end
