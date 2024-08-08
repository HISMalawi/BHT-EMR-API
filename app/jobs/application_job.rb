# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  unique :until_executing, on_conflict: :log
  
  def login(user_id, location_id)
    User.current = User.find(user_id)
    Location.current = Location.find(location_id)
  end
end
