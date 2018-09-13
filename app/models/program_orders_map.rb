# frozen_string_literal: true

class ProgramOrdersMap < ApplicationRecord
  self.table_name = 'program_orders_map'
  self.primary_key = 'program_orders_map_id'

  belongs_to :program, conditions: { retired: 0 }
  belongs_to :concept, conditions: { retired: 0 }
end
