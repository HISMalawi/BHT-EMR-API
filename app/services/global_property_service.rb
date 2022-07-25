# frozen_string_literal: true

##
# A collection of various helpers for dealing with global properties
module GlobalPropertyService
  class << self
    def use_filing_numbers?
      GlobalProperty.where(property: 'use.filing.number', property_value: 'true')
                    .exists?
    end

    def site_code
      property = GlobalProperty.find_by(property: 'site_prefix')
      value = property&.property_value&.strip

      raise "Global property 'site_prefix' not set" unless value

      value
    end
  end
end
