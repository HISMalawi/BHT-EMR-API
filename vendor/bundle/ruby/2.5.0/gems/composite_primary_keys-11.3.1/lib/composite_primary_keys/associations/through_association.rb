module ActiveRecord
  module Associations
    module ThroughAssociation
      alias :original_construct_join_attributes :construct_join_attributes

      def construct_join_attributes(*records)
        # CPK
        if source_reflection.klass.composite?
          ensure_mutable

          ids = records.map do |record|
            source_reflection.association_primary_key(reflection.klass).map do |key|
              record.send(key)
            end
          end

          cpk_in_predicate(through_association.scope.klass.arel_table, source_reflection.foreign_key, ids)
        else
          original_construct_join_attributes(*records)
        end
      end
    end
  end
end
