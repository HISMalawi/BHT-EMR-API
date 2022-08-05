class ProviderAttributeType < VoidableRecord
  self.table_name = :provider_attribute_type
  self.primary_key = :provider_attribute_type_id
  belongs_to :creator, class_name: 'User', foreign_key: 'creator'
  belongs_to :changed_by, class_name: 'User', foreign_key: 'changed_by'
end
