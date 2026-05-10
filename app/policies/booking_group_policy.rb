class BookingGroupPolicy < ApplicationPolicy
  def show?   = owner_or_patient?
  def create? = user.patient?
  def cancel? = owner_or_patient? && record.pending?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.owner? || user.dentist?
        scope.where(clinic_id: user.clinic_id)
      else
        scope.where(patient_id: user.id)
      end
    end
  end

  private

  def owner_or_patient?
    user.owner? || user.dentist? || record.patient_id == user.id
  end
end
