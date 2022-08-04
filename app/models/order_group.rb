class OrderGroup < VoidableRecord
  self.table_name = :order_group
  self.primary_key = :order_group_id

  belongs_to :order_set, foreign_key: :order_set_id
  belongs_to :patient, foreign_key: :patient_id
  belongs_to :encounter, foreign_key: :encounter_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator
end
