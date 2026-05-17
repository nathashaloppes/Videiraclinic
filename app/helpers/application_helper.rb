module ApplicationHelper
  include Pagy::Frontend

  def booking_group_status_class(_status)
    "text-xs px-3 py-1 rounded-full font-semibold"
  end

  def booking_group_status_style(status)
    {
      "pending"   => "background-color: #FFF9C4; color: #F57F17",
      "confirmed" => "background-color: #E8F5E9; color: #388E3C",
      "cancelled" => "background-color: #F5F5F5; color: #757575",
      "expired"   => "background-color: #FFEBEE; color: #d4183d"
    }.fetch(status.to_s, "background-color: #F5F5F5; color: #757575")
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
