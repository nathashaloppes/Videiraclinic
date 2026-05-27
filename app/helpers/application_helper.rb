module ApplicationHelper
  include Pagy::Frontend

  def booking_group_status_badge(status)
    {
      "pending"   => "badge-warning",
      "confirmed" => "badge-success",
      "cancelled" => "badge-neutral",
      "expired"   => "badge-danger"
    }.fetch(status.to_s, "badge-neutral")
  end

  def payment_status_badge(status)
    {
      "pending"   => "badge-warning",
      "paid"      => "badge-success",
      "failed"    => "badge-danger",
      "cancelled" => "badge-neutral",
      "expired"   => "badge-danger"
    }.fetch(status.to_s, "badge-neutral")
  end

  def money(cents)
    number_with_precision(cents / 100.0, precision: 2, delimiter: ".", separator: ",")
  end

  # Returns an inline onclick JS string to open a <dialog> by id.
  # Usage: onclick="<%= open_modal('my-dialog') %>"
  def open_modal(id)
    "document.getElementById('#{html_escape(id)}').showModal()"
  end
end
