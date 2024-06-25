# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Various helper methods for modules in the Lims namespaces...
    module Utils
      def logger
        Rails.logger
      end

      def structify(object)
        if object.is_a?(Hash)
          object.each_with_object(OpenStruct.new) do |kv_pair, struct|
            key, value = kv_pair

            struct[key] = structify(value)
          end
        elsif object.respond_to?(:map)
          object.map { |item| structify(item) }
        else
          object
        end
      end
    end
  end
end
