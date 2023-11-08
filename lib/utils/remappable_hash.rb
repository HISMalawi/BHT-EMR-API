# frozen_string_literal: true

module Utils
  module RemappableHash
    def remap_field!(old_name, new_name)
      raise KeyError, "Can't remap non-existent field: #{old_name}" unless include? old_name

      self[new_name] = delete old_name
    end
  end
end

class Hash
  include Utils::RemappableHash
end

# A blessing to Rails params
module ActionController
  class Parameters
    include Utils::RemappableHash
  end
end
