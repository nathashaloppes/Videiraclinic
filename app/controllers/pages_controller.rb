class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def home
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @availabilities = Availability
      .available
      .where(date: @date, clinic: Clinic.first)
      .includes(:service, :dentist)
      .order(:starts_at)
  rescue Date::Error
    @date = Date.current
    retry
  end

  def about; end
  def contact; end
end
