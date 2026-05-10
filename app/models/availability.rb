class Availability < ApplicationRecord
  has_paper_trail skip: [:status]

  belongs_to :clinic
  belongs_to :service
  belongs_to :dentist, class_name: "User"
  has_one    :booking

  validates :date,      presence: true
  validates :starts_at, presence: true
  validates :ends_at,   presence: true

  enum :status, {
    available:  "available",
    booked:     "booked",
    cancelled:  "cancelled",
    blocked:    "blocked"
  }

  scope :available,  -> { where(status: "available") }
  scope :future,     -> { where("date >= ?", Date.current) }
  scope :for_date,   ->(date) { where(date: date) }

  def cancellable?
    return false unless available?
    slot_start = Time.zone.local(date.year, date.month, date.day, starts_at.hour, starts_at.min)
    lead_hours  = ENV.fetch("CANCELLATION_LEAD_HOURS", 48).to_i
    slot_start > lead_hours.hours.from_now
  end
end
