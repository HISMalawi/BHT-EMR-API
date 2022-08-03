# frozen_string_literal: true

# class modeling the cohort table
class Cohort < VoidableRecord
  # specify the table name
  self.table_name = :cohort
  # specify the primary key
  self.primary_key = :cohort_id
end
