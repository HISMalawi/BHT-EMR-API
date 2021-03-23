# frozen_string_literal: true

module Remmapable
  def remap_field!(old_name, new_name)
    raise KeyError, "Can't remap non-existent field: #{old_name}" unless include? old_name
    self[new_name] = delete old_name
  end
end

class Hash
  include Remmapable
end

# A blessing to Rails params
class ActionController::Parameters
  include Remmapable
end
