class RemoveProgramReferenceToEncounter < ActiveRecord::Migration[5.2]
  def up
    execute "ALTER TABLE encounter DROP FOREIGN KEY program_id;";
    execute "ALTER TABLE encounter DROP COLUMN program_id;";
  end
    
  def down
    
  end
end


