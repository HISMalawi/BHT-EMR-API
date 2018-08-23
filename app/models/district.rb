class District < ActiveRecord::Base
	self.table_name = "district"
	self.primary_key = "district_id"

	belongs_to :region

end
