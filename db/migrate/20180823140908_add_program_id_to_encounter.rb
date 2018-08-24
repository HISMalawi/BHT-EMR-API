class AddProgramIdToEncounter < ActiveRecord::Migration[5.2]
  def self.up
  	 add_column :encounter, :program_id, :integer
  end
  def self.down
  	remove_column :encounter, :program_id
  end
end
