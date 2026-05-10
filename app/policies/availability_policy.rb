class AvailabilityPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = user.owner? || user.dentist?
  def update? = user.owner? || user.dentist?
  def destroy? = user.owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(clinic_id: user.clinic_id) if user.owner? || user.dentist?
      scope.available.future
    end
  end
end
