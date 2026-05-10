class BookingPolicy < ApplicationPolicy
  def show?   = owner_or_patient?
  def cancel? = record.confirmed? && owner_or_patient?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.owner? || user.dentist?
        scope.joins(:booking_group).where(booking_groups: { clinic_id: user.clinic_id })
      else
        scope.where(patient_id: user.id)
      end
    end
  end

  private

  def owner_or_patient?
    user.owner? || record.patient_id == user.id
  end
end
