class AddEncounterProgramReferenceId < ActiveRecord::Migration[5.2]
  def up
    execute "ALTER TABLE encounter ADD program_id INT(11);";
    execute "ALTER TABLE encounter ADD CONSTRAINT program_id FOREIGN KEY (program_id) REFERENCES program(program_id);";
  end
    
  def down
    execute "ALTER TABLE encounter DROP FOREIGN KEY program_id;";
    execute "ALTER TABLE encounter DROP COLUMN program_id;";
  end
end
