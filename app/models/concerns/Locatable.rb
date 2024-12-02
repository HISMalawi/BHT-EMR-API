# this class is responsible for assigning a 
# site id to a record on save

# when a table has a site id attached to it, 
# make sure its assigned during save
# the site_id is collected from the logged in user who belongs to a location

module Locatable
  extend ActiveSupport::Concern
  
  included do
    default_scope { where(site_id: current_location_id) } if has_site_id_column?
    
    validates :site_id, presence: true
  end
  
  
  class_methods do
    
    def has_site_id_column?
      self.column_names.include?('site_id')
    end
    
    def current_location_id
      User.current&.current_location&.id || Location.current_health_center&.id
    end

  end
end