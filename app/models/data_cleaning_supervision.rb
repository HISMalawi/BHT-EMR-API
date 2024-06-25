# frozen_string_literal: true

# Data Cleaning Supervision model
class DataCleaningSupervision < VoidableRecord
  self.table_name = :data_cleaning_supervisions
  self.primary_key = :data_cleaning_tool_id

  # belongs to users table
  belongs_to :created_by, class_name: 'User', foreign_key: :creator, optional: true
  belongs_to :voider, class_name: 'User', foreign_key: :voided_by
  belongs_to :updated_by, class_name: 'User', foreign_key: :changed_by, optional: true

  def as_json(options = {})
    super(options.merge(
      only: %i[data_cleaning_tool_id data_cleaning_datetime comments],
      include: {
        created_by: { only: %i[user_id username] },
        updated_by: { only: %i[user_id username] }
      },
      methods: %i[all_supervisors]
    ))
  end

  def all_supervisors
    supervisors.split(';')
  end
end
