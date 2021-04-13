class VoidableRecord < ApplicationRecord
  self.abstract_class = true

  include Auditable
  include Voidable

  default_scope { where(voided: 0) }

  belongs_to :creator_user, foreign_key: 'creator', class_name: 'User', optional: true
end
