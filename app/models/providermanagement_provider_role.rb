class ProvidermanagementProviderRole < RetirableRecord
  self.table_name = :providermanagement.provider_role
  self.primary_key = :provider_role_id
  belongs_to :creator, class_name: 'User', foreign_key: 'creator'
  belongs_to :changed_by, class_name: 'User', foreign_key: 'changed_by'
end
