# frozen_string_literal: true

print "Clearing cohort_drill_down table...\n"

ActiveRecord::Base.connection.execute(
  <<~SQL
    TRUNCATE cohort_drill_down;
  SQL
)
