class Payments::PaymentsController < ApplicationController
  def show
    @payment = policy_scope(Payment)
      .includes(booking_group: [:bookings, :dentist])
      .find(params[:id])
    authorize @payment
  end

  def pending
    @payment = policy_scope(Payment).find(params[:id])
    authorize @payment, :show?
  end

  def cancel
    @payment = policy_scope(Payment).find(params[:id])
    authorize @payment, :show?

    group = @payment.booking_group
    return redirect_to pagamento_path(@payment), alert: "Pagamento já processado." unless group.pending?

    ActiveRecord::Base.transaction do
      @payment.update!(status: "cancelled")
      group.cancel!
    end

    redirect_to reservas_path, notice: "Reserva cancelada."
  rescue => e
    redirect_to pagamento_path(@payment), alert: "Não foi possível cancelar: #{e.message}"
  end
end
