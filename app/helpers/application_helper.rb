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

  def format_cpf(value)
    digits = value.to_s.gsub(/\D/, "")
    return value if digits.length != 11
    "#{digits[0,3]}.#{digits[3,3]}.#{digits[6,3]}-#{digits[9,2]}"
  end

  def format_phone(value)
    digits = value.to_s.gsub(/\D/, "")
    case digits.length
    when 11 then "(#{digits[0,2]}) #{digits[2,5]}-#{digits[7,4]}"
    when 10 then "(#{digits[0,2]}) #{digits[2,4]}-#{digits[6,4]}"
    else value
    end
  end

  # Returns an inline onclick JS string to open a <dialog> by id.
  # Usage: onclick="<%= open_modal('my-dialog') %>"
  def open_modal(id)
    "document.getElementById('#{html_escape(id)}').showModal()"
  end
end
