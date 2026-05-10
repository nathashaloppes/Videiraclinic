class Auth::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!, only: [:new, :create]

  private

  def sign_up_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation,
      :phone, :birth_date, :cpf)
  end

  def account_update_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation,
      :current_password, :phone, :birth_date, :cpf, :avatar)
  end
end
