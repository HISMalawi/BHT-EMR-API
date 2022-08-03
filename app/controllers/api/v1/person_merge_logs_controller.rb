class Api::V1::PersonMergeLogsController < ApplicationController
  before_action :set_person_merge_log, only: %i[show update destroy]

  # GET /person_merge_logs
  def index
    @person_merge_logs = PersonMergeLog.all

    render json: @person_merge_logs
  end

  # GET /person_merge_logs/1
  def show
    render json: @person_merge_log
  end

  # POST /person_merge_logs
  def create
    @person_merge_log = PersonMergeLog.new(person_merge_log_params)

    if @person_merge_log.save
      render json: @person_merge_log, status: :created
    else
      render json: @person_merge_log.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /person_merge_logs/1
  def update
    if @person_merge_log.update(person_merge_log_params)
      render json: @person_merge_log
    else
      render json: @person_merge_log.errors, status: :unprocessable_entity
    end
  end

  # DELETE /person_merge_logs/1
  def destroy
    @person_merge_log.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_person_merge_log
    @person_merge_log = PersonMergeLog.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def person_merge_log_params
    params.require(:person_merge_log).permit(:person_merge_log_id, :winner_person_id, :loser_person_id, :creator,
                                             :date_created, :merged_data, :changed_by, :date_changed, :voided, :voided_by, :date_voided, :void_reason, :uuid)
  end
end
