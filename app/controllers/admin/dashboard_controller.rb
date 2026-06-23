class Admin::DashboardController < Admin::BaseController
  def index
    clinic = current_user.clinic

    # Reservas confirmadas para hoje
    @todays_bookings = Booking.where(clinic: clinic, status: "confirmed")
      .joins(:availability)
      .where(availabilities: { date: Date.current }).count

    # Turnos no carrinho ainda não pagos (grupos com pagamento pendente)
    @pending_payments = Booking.where(clinic: clinic)
      .joins(booking_group: :payment)
      .where(payments: { status: "pending" }).count

    # Receita = dinheiro EXTERNO recebido (Pix/admin) das reservas confirmadas.
    # Pagamentos com crédito do cliente NÃO contam — esse valor não é dinheiro
    # novo (já entrou na recarga ou é promocional). Reservas canceladas/expiradas
    # também não entram. Cada pagamento conta uma vez (evita contagem dupla).
    range = Date.current.beginning_of_month..Date.current.end_of_month
    @monthly_turnos, @monthly_insumos = revenue_split(clinic, range)
    @monthly_revenue = @monthly_turnos + @monthly_insumos

    @monthly_series = build_monthly_series(clinic, months: 6)
  end

  private

  # Soma o dinheiro externo recebido no período, separando turnos de insumos.
  def revenue_split(clinic, range)
    turnos = insumos = 0
    cash_payments(clinic, range).group_by(&:booking_group_id).each do |_gid, payments|
      cash = payments.sum { |p| p.amount_cents.to_i }
      ins  = payments.sum { |p| extras_cents(p.extras) }
      ins  = extras_cents(payments.first.booking_group&.extras) if ins.zero? # dados antigos
      ins  = [ins, cash].min
      insumos += ins
      turnos  += cash - ins
    end
    [turnos, insumos]
  end

  # Pagamentos pagos, externos (não-crédito), de reservas confirmadas.
  def cash_payments(clinic, range)
    Payment.paid.where(clinic: clinic, paid_at: range)
      .where.not(gateway: "credit")
      .joins(:booking_group).where(booking_groups: { status: "confirmed" })
      .includes(:booking_group)
      .to_a
  end

  def extras_cents(extras)
    Array(extras).sum { |e| e["price_cents"].to_i * e["quantity"].to_i }
  end

  def build_monthly_series(clinic, months:)
    today = Date.current
    (0...months).map { |i| (today << i).beginning_of_month }.reverse.map do |start|
      range = start..start.end_of_month
      cents = cash_payments(clinic, range).sum { |p| p.amount_cents.to_i }
      { month: start, cents: cents }
    end
  end
end
