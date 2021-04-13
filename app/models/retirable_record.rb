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

  belongs_to :creator_user, foreign_key: 'creator', class_name: 'User'

  def void(*args, **kwargs)
    # HACK: This should normally be called within the top most scope of
    # a class but we are calling it here as it seems not work through
    # more than 1 level of inheritance.
    self.class.remap_voidable_interface(
      voided: :retired, date_voided: :date_retired,
      void_reason: :retire_reason, voided_by: :retired_by
    )

    super(*args, **kwargs)
  end
end
