class Provider < RetirableRecord
  self.table_name = :provider
  self.primary_key = :provider_id
  belongs_to :person
  belongs_to :providermanagement_provider_role
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :changed_by, class_name: 'User', foreign_key: :changed_by_id
end
