class Admin::BaseController < ApplicationController
  before_action :require_owner!

  layout "admin"

  private

  def require_owner!
    redirect_to root_path, alert: "Acesso restrito ao proprietário." unless current_user&.owner?
  end
end
