class VoidableRecord < ApplicationRecord
  self.abstract_class = true

  include Auditable
  include Voidable

  default_scope { where(voided: 0) }
end
