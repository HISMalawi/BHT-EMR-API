class UserProgram < ApplicationRecord
	
  self.table_name = 'user_programs'
  self.primary_key = 'id'
	belongs_to :user, foreign_key: :user_id
  belongs_to :program, foreign_key: :program_id

	validates_presence_of :user_id, :program_id
end