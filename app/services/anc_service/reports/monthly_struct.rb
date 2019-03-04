# frozen_string_literal: true

module ANCService
    module Reports
      require 'ostruct'
  
      class MonthlyStruct
        FIELD_DESCRIPTIONS = {
          # Table contains various fields of the Cohort report and their descriptions.
          # A fields description is simply "Indicator: Human Readable Name",
          # or "Human Readable Name". The former is for fields with an indicator
          # label and the latter is for fields without.
          
          
        }.freeze
  
        def initialize
          @values = ActiveSupport::HashWithIndifferentAccess.new
        end
  
        def method_missing(name, *args, &block)
          name_prefix, name_suffix = split_missing_method_name(name)
  
          return super(name, *args, &block) unless FIELD_DESCRIPTIONS.include?(name_prefix)
  
          field = value(name_prefix)
          field.contents = args[0] if name_suffix == '='
          field.contents
  
          field.contents
        end
  
        #def respond_to_missing?(name)
        #  field_name, = split_missing_method_name(name)
        #  FIELD_DESCRIPTIONS.include?(field_name)
        #end
  
        def values
          @values.values
        end
  
        private
  
        # Returns a ReportValue object for the given name
        def value(name)
          description = FIELD_DESCRIPTIONS[name]
          iname_parts = description.split(':', 2)
          iname_parts.insert(0, nil) unless iname_parts.size == 2
          short_iname, long_iname = iname_parts
  
          @values[name] ||= OpenStruct.new(
            name: name,
            indicator_name: long_iname.strip,
            indicator_short_name: short_iname ? short_iname.strip : short_iname,
            description: description,
            contents: nil
          )
        end
  
        def split_missing_method_name(name)
          match = name.to_s.match(/^([_A-Z0-9]+)(=)?$/i)
          [match[1].to_sym, match[2]]
        end
      end
    end
  end