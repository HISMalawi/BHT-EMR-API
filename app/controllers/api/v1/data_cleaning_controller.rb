class Api::V1::DataCleaningController < ApplicationController
	def view
		render json: DataCleaningSupervision.all.collect { |tool|
			{
				data_cleaning_tool_id: tool.data_cleaning_tool_id,
				data_cleaning_datetime: tool.data_cleaning_datetime,
				supervisors: tool.supervisors.split(';'),
				date_created: tool.created_at
			}
		}
	end

	def create
		data = {
			data_cleaning_datetime: params[:data_cleaning_datetime],
			supervisors: params[:supervisors].join(";"),
			creator: User.current.user_id
		}

		@data_cleaning_tool = DataCleaningSupervision.create(data)
		render json: {
			data_cleaning_tool_id: @data_cleaning_tool.data_cleaning_tool_id,
			supervision_datetime: @data_cleaning_tool.data_cleaning_datetime,
			supervisors: @data_cleaning_tool.supervisors.split(";").map(&:strip)
		}
	end

end
