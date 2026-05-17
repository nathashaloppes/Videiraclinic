class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    scope = policy_scope(User).where.not(role: "owner").order(:name)
    scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @pagy, @users = pagy(scope)
  end

  def show
    @booking_groups = @user.booking_groups
      .includes(:bookings, :payment)
      .order(created_at: :desc)
      .limit(10)
    @versions = @user.versions.order(created_at: :desc).limit(20)
  end

  def edit; end

  def update
    if @user.update(admin_user_params)
      redirect_to admin_user_path(@user), notice: "Usuário atualizado."
    else
      redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "Não é possível excluir seu próprio usuário."
    else
      @user.destroy!
      redirect_to admin_users_path, notice: "Usuário removido."
    end
  end

  private

  def set_user
    @user = policy_scope(User).find(params[:id])
  end

  def admin_user_params
    # email não é permitido — proteção contra injection via params
    params.require(:user).permit(:name, :phone, :birth_date, :cpf, :role)
  end
end
