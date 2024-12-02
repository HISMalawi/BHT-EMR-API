# this class is responsible for assigning a 
# site id to a record on save

# when a table has a site id attached to it, 
# make sure its assigned during save
# the site_id is collected from the logged in user who belongs to a location

class LocatableRecord < ApplicationRecord
  self.abstract_class = true
  
  def has_site_id_column?
    puts "checking has_site_id_column?"
    respond_to?(:site_id)
  end
  
  default_scope { where(site_id: current_location_id) } if has_site_id_column?
  
  validates :site_id, presence: true
  
  def site_id
    current_location_id
  end
  
  def self.current_location_id
    User.current&.current_location&.id || Location.first.id
  end
  
end