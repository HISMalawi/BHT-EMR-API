module CompositePrimaryKeys
  module ActiveRecord
    module Batches
      def in_batches(of: 1000, start: nil, finish: nil, load: false, error_on_ignore: nil)
        relation = self
        unless block_given?
          return BatchEnumerator.new(of: of, start: start, finish: finish, relation: self)
        end

        if arel.orders.present?
          act_on_ignored_order(error_on_ignore)
        end

        batch_limit = of
        if limit_value
          remaining   = limit_value
          batch_limit = remaining if remaining < batch_limit
        end

        relation = relation.reorder(batch_order).limit(batch_limit)
        relation = apply_limits(relation, start, finish)
        relation.skip_query_cache! # Retaining the results in the query cache would undermine the point of batching
        batch_relation = relation

        loop do
          if load
            records = batch_relation.records
            ids = records.map(&:id)
            # CPK
            # yielded_relation = self.where(primary_key => ids)
            yielded_relation = self.where(cpk_in_predicate(table, primary_keys, ids))
            yielded_relation.load_records(records)
          else
            # CPK
            # ids = batch_relation.pluck(primary_key)
            ids = batch_relation.pluck(*Array(primary_keys))
            # CPK
            # yielded_relation = self.where(primary_key => ids)
            yielded_relation = self.where(cpk_in_predicate(table, primary_keys, ids))
          end

          break if ids.empty?

          primary_key_offset = ids.last
          raise ArgumentError.new("Primary key not included in the custom select clause") unless primary_key_offset

          yield yielded_relation

          break if ids.length < batch_limit

          if limit_value
            remaining -= ids.length

            if remaining == 0
              # Saves a useless iteration when the limit is a multiple of the
              # batch size.
              break
            elsif remaining < batch_limit
              relation = relation.limit(remaining)
            end
          end

          # CPK
          # batch_relation = relation.where(arel_attribute(primary_key).gt(primary_key_offset))
          batch_relation = if composite?
            # CPK
            # Lexicographically select records
            #
            query = prefixes(primary_key.zip(primary_key_offset)).map do |kvs|
              and_clause = kvs.each_with_index.map do |(k, v), i|
                # Use > for the last key in the and clause
                # otherwise use =
                if i == kvs.length - 1
                  table[k].gt(v)
                else
                  table[k].eq(v)
                end
              end.reduce(:and)

              Arel::Nodes::Grouping.new(and_clause)
            end.reduce(:or)
            relation.where(query)
          else
            relation.where(arel_attribute(primary_key).gt(primary_key_offset))
          end
        end
      end

      private

      # CPK Helper method to collect prefixes of an array:
      # prefixes([:a, :b, :c]) => [[:a], [:a, :b], [:a, :b, :c]]
      #
      def prefixes(ary)
        ary.length.times.reduce([]) { |results, i| results << ary[0..i] }
      end

      def batch_order
        self.primary_key.map do |key|
          arel_attribute(key).asc
        end
      end
    end
  end
end
