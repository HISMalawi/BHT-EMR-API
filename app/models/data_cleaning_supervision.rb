# frozen_string_literal: true

class DataCleaningSupervision < ApplicationRecord
  self.table_name = :data_cleaning_supervisions
  self.primary_key = :data_cleaning_tool_id

  default_scope { where(voided: 0) }
end
