# frozen_string_literal: true

# Base class for models that define the voidable interface.
#
# Models defining the voidable interface must define the following
# attributes:
#   1. retired:integer - Takes on 0 for off and 1 if voided
#   2. date_retired:datetime
#   3. retired_reason:string
#   4. retired_by:long
class RetirableRecord < ApplicationRecord
  self.abstract_class = true

  include Auditable
  include Voidable

  default_scope { where(retired: 0) }

  remap_voidable_interface(
    voided: :retired, date_voided: :date_retired,
    void_reason: :retire_reason, voided_by: :retired_by
  )
end
