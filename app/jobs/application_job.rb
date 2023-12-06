class ApplicationJob < ActiveJob::Base
  def login(user_id, location_id)
    User.current = User.find(user_id)
    Location.current = Location.find(location_id)
  end
end
