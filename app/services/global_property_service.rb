# frozen_string_literal: true

##
# A collection of various helpers for dealing wi
module GlobalPropertyService
  def self.use_filing_numbers?
    GlobalProperty.where(property: 'use.filing.number', property_value: 'true')
                  .exists?
  end
end
