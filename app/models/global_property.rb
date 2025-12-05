# frozen_string_literal: true

class GlobalProperty < ApplicationRecord
  self.table_name = :global_property
  # self.primary_key = :property

  include Locatable
end
