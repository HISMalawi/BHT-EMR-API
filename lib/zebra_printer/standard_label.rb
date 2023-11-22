# frozen_string_literal: true

module ZebraPrinter
  class StandardLabel < Label
    def initialize
      dimensions = begin
        GlobalProperty.find_by_property('label_width_height').property_value
      rescue StandardError
        nil || '801,329'
      end.split(',').collect(&:to_i)
      super(dimensions.first, dimensions.last, 'T')
    end
  end
end
