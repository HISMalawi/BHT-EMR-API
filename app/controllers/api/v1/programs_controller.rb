class Api::V1::ProgramsController < ApplicationController
  def show
    render json: Program.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    query = name ? Program.where('name like ?', "%#{name}%") : Program
    render json: paginate(query)
  end

  def create
    create_params = params.require(:program).permit(%i[concept_id name description])

    program = Program.create create_params
    if program.errors.empty?
      render json: program, status: :created
    else
      render json: program.errors, status: :bad_request
    end
  end

  def update
    update_params = params.require(:program).permit(%i[concept_id name description])

    program = Program.find(params[:id])
    if program.update update_params
      render json: program, status: :ok
    else
      render json: program.errors, status: :bad_request
    end
  end

  def destroy
    program = Program.find(params[:id])
    if program.destroy
      render status: :no_content
    else
      render json: program.errors, status: :internal_server_error
    end
  end

  def booked_appointments
    program_id = params[:program_id]
    date = params[:date].to_date

    list = ProgramAppointmentService.booked_appointments program_id, date
    render json: list
  end
end
