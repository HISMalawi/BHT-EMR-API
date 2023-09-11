module LaboratoryService
  module Reports
    module Clinic
      class SamplesDrawn
        def initialize(start_date:, end_date: nil, **_kwargs)
          @start_date = start_date.to_date
          @end_date = end_date&.to_date || Date.today
        end

        def samples_drawn
          read
        end

        def test_results
          ProcessedResults.new(start_date: @start_date, end_date: @end_date).read
        end

        def read
          query.map do |row|
            row = row.dup
            row['tests'] = row['tests'].split(',')

            row
          end
        end

        def orders_made(status)
          query2 status
        end

        private

        def query
          start_date = ActiveRecord::Base.connection.quote(@start_date)
          end_date = ActiveRecord::Base.connection.quote(@end_date)

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT orders.start_date AS order_date,
                   COALESCE(orders.discontinued_date, orders.start_date) AS sample_drawn_date,
                   orders.patient_id,
                   specimen.name AS specimen,
                   person.gender,
                   person.birthdate,
                   patient_identifier.identifier AS arv_number,
                   disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                   reason_for_test.name AS reason_for_test,
                   GROUP_CONCAT(DISTINCT test_concepts.name SEPARATOR ',') AS tests
            FROM orders
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name AS specimen
              ON specimen.concept_id = orders.concept_id
            INNER JOIN obs AS test_obs
              ON test_obs.order_id = orders.order_id
              AND test_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Test type' AND voided = 0)
              AND test_obs.voided = 0
            INNER JOIN (
              SELECT concept_id, name FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE retired = 0 AND concept_name_type = 'FULLY_SPECIFIED'
              GROUP BY concept_id
            ) AS test_concepts
              ON test_concepts.concept_id = test_obs.value_coded
            LEFT JOIN obs AS reason_for_test_obs
              ON reason_for_test_obs.order_id = orders.order_id
              AND reason_for_test_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Reason for test' AND voided = 0)
              AND reason_for_test_obs.voided = 0
            LEFT JOIN concept_name AS reason_for_test
              ON reason_for_test.concept_id = reason_for_test_obs.value_coded
            INNER JOIN person
              ON person.person_id = orders.patient_id
              AND person.voided = 0
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (
                SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name LIKE 'ARV Number'
              )
            WHERE orders.concept_id NOT IN (SELECT concept_id FROM concept_name WHERE name IN ('Unknown', 'Tests ordered') AND voided = 0)
              AND orders.voided = 0
              AND ((orders.discontinued_date >= DATE(#{start_date})
                    AND orders.discontinued_date < DATE(#{end_date}) + INTERVAL 1 DAY)
                   OR (orders.discontinued_date IS NULL
                       AND orders.start_date >= DATE(#{start_date})
                       AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY))
            GROUP BY orders.order_id
          SQL
        end

        def query2(status)
          start_date = ActiveRecord::Base.connection.quote(@start_date)
          end_date = ActiveRecord::Base.connection.quote(@end_date)

          additional_sql = (status == 'drawn' ? " AND `orders`.`concept_id`
          NOT IN (SELECT `concept_name`.`concept_id` FROM `concept_name`
          WHERE `concept_name`.`voided` = 0 AND `concept_name`.`name` = 'Unknown')" : '')

          orders = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT `orders`.`order_id` FROM `orders` INNER JOIN `order_type`
            ON `order_type`.`retired` = 0 AND `order_type`.`order_type_id` = `orders`.`order_type_id`
            WHERE `orders`.`voided` = 0 AND `order_type`.`retired` = 0
            AND `order_type`.`name` = 'Lab'
            AND (DATE(start_date) BETWEEN #{start_date} AND #{end_date})
            #{additional_sql} ORDER BY `orders`.`start_date` DESC;
          SQL

          return [] if orders.blank?
          order_ids = orders.map{|order| order['order_id'].to_i}

          tests = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT `obs`.*, concept_name.name FROM `obs` INNER JOIN concept_name
            ON concept_name.concept_id = obs.value_coded
            WHERE `obs`.`voided` = 0 AND concept_name.voided = 0
            AND (`obs`.`concept_id`) IN (SELECT `concept_name`.`concept_id` FROM `concept_name`
            WHERE `concept_name`.`voided` = 0 AND `concept_name`.`name` = 'Test type')
            AND (`obs`.`order_id`) IN (#{order_ids.join(',')}) GROUP BY obs.order_id;
          SQL

          return tests.map do |t|
            { name: t['name'], concept_id: t['value_coded'].to_i }
          end
        end



      end
    end
  end
end
