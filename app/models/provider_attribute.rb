class ProviderAttribute < VoidableRecord
  belongs_to :provider
  belongs_to :provider_attribute_type
  belongs_to :creator, class_name: 'User', foreign_key: 'creator'
  belongs_to :changed_by, class_name: 'User', foreign_key: 'changed_by'
end
