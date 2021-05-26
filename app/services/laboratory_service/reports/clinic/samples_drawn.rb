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
          return processed_results
        end

        def read
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
                   cohort_disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                   reason_for_test.name AS reason_for_test
            FROM orders
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name AS specimen
              ON specimen.concept_id = orders.concept_id
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
      end
    end
  end
end
