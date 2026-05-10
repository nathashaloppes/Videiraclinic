module ApplicationHelper
  include Pagy::Frontend

  def booking_group_status_class(status)
    {
      "pending"   => "bg-yellow-100 text-yellow-800",
      "confirmed" => "bg-green-100 text-green-800",
      "cancelled" => "bg-gray-100 text-gray-600",
      "expired"   => "bg-red-100 text-red-700"
    }.fetch(status.to_s, "bg-gray-100 text-gray-600")
  end

  def money(cents)
    number_with_precision(cents / 100.0, precision: 2, delimiter: ".", separator: ",")
  end
end
