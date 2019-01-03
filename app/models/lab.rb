class Lab < ApplicationRecord
  self.table_name = :map_lab_panel

  use_healthdata_db
end
