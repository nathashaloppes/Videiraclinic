class Admin::BookingsController < Admin::BaseController
  before_action :set_booking_group, only: [:show, :cancel]

  def index
    scope = policy_scope(BookingGroup)
      .includes(:patient, :bookings, :payment)
      .order(created_at: :desc)

    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.joins(bookings: :availability)
                 .where(availabilities: { date: Date.parse(params[:date]) }) if params[:date].present?

    @pagy, @booking_groups = pagy(scope)
  end

  def show
    @versions = @booking_group.versions + @booking_group.bookings.flat_map(&:versions)
    @versions.sort_by!(&:created_at).reverse!
  end

  def cancel
    result = BookingCanceller.call(booking: @booking_group.bookings.confirmed.first)

    if result.success?
      redirect_to admin_booking_path(@booking_group), notice: "Reserva cancelada."
    else
      redirect_to admin_booking_path(@booking_group), alert: result.error
    end
  end

  private

  def set_booking_group
    @booking_group = policy_scope(BookingGroup).find(params[:id])
  end
end
