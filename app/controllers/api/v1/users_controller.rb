class Api::V1::UsersController < Api::V1::BaseController
  before_action :load_resource
  before_action :authenticate_user, only: [:index, :show]

  def index

  end

  def show

  end

  def create

  end

  def update

  end

  def destroy

  end

  private
  def load_resource
    case params[:action].to_sym
      when :index
        @users = paginate(apply_filters(User.all, params))
      when :create
        @user = User.new(create_params)
      when :show, :update, :destroy
        @user = User.find(params[:id])
    end
  end
end