# frozen_string_literal: true

class GlobalProperty < ApplicationRecord
  include Locatable
  self.table_name = :global_property
  self.primary_key = :property
end
