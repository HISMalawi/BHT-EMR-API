# frozen_string_literal: true

# class modeling cohort member table
class CohortMember < VoidableRecord
  self.table_name = :cohort_member
  self.primary_key = :cohort_member_id
end
