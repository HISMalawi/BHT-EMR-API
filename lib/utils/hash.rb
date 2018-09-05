# frozen_string_literal: true

# Extensions to the builtin Hash
class Hash
  def remap_field!(old_name, new_name)
    raise KeyError, "Can't remap non-existent field: #{old_name}" unless include? old_name
    self[new_name] = delete old_name
  end
end
