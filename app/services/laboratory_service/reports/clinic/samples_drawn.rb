module LaboratoryService
  module Reports
    module Clinic

      class SamplesDrawn
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def samples_drawn
          return drawn
        end

        def test_results
          return processed_results
        end

        private

        def drawn
          unknown_concept = concept 'Unknown'
          test_type = concept 'Test type'
          reason_for_test = concept 'Reason for test'
          order_type_id = OrderType.find_by_name('Lab').id
          arv_identifier_type = PatientIdentifierType.find_by_name('ARV number').id

          drawn_samples = Observation.where("orders.concept_id NOT IN(?) AND start_date
          BETWEEN ? AND ? AND obs.concept_id = ?", unknown_concept.concept_id,
          @start_date, @end_date, test_type.concept_id).\
          joins("INNER JOIN orders ON obs.order_id = orders.order_id
          AND orders.order_type_id = #{order_type_id} AND orders.voided = 0
          INNER JOIN obs r ON orders.order_id = r.order_id
          AND r.concept_id = #{reason_for_test.concept_id} AND r.voided = 0
          INNER JOIN concept_name cn ON cn.concept_id = obs.value_coded
          INNER JOIN concept_name cnr ON cnr.concept_id = r.value_coded
          INNER JOIN person p ON p.person_id = orders.patient_id
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
          AND i.voided = 0 AND i.identifier_type = #{arv_identifier_type}").\
          select("orders.patient_id, cn.name test_name, orders.order_id, cnr.name reason_for_test,
          p.birthdate, p.gender, orders.start_date, i.identifier arv_number,
          cohort_disaggregated_age_group(birthdate, '#{@end_date.to_date}') age_group").\
          group("orders.order_id, orders.concept_id").order("i.date_created DESC")

          return drawn_samples.map do |sample|
            {
              order_date: sample.start_date.to_date,
              gender: sample.gender,
              birthdate: sample.birthdate,
              test: sample.test_name,
              age_group: sample.age_group,
              arv_number: sample.arv_number,
              reason_for_test: sample.reason_for_test,
              patient_id: sample.patient_id
            }
          end
        end

        def processed_results
          unknown_concept = concept 'Unknown'
          lab_test_result = concept 'Lab test result'
          reason_for_test = concept 'Reason for test'
          order_type_id = OrderType.find_by_name('Lab').id
          arv_identifier_type = PatientIdentifierType.find_by_name('ARV number').id

          concepts_to_ignore = ConceptName.where("name IN(?)",['Lab test result','Lab',
            'Reason for test','Person making request','Test type']).map(&:concept_id)

          results = Observation.where("t.concept_id NOT IN(?) AND t.start_date
          BETWEEN ? AND ?", unknown_concept.concept_id, @start_date, @end_date)\
          .joins("INNER JOIN orders t ON t.order_id = obs.order_id AND t.voided = 0
          AND obs.concept_id = #{lab_test_result.concept_id}
          INNER JOIN obs t2 ON t2.order_id = obs.order_id
          AND t2.concept_id NOT IN(#{concepts_to_ignore.join(',')})
          LEFT JOIN obs t3 ON t3.order_id = t2.order_id
          AND t3.voided = 0 AND t3.concept_id = #{reason_for_test.concept_id}
          INNER JOIN concept_name rft ON rft.concept_id = t3.value_coded
          INNER JOIN person p ON p.person_id = obs.person_id
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
          AND i.voided = 0 AND i.identifier_type = #{arv_identifier_type}
          INNER JOIN concept_name test ON test.concept_id = t2.concept_id").\
          group("obs.order_id").select("p.person_id patient_id, p.gender, p.birthdate,
          t.start_date, t2.value_modifier, t2.obs_datetime result_date,
          test.name test_name, i.identifier arv_number,  IF(t2.value_numeric IS NULL,
          t2.value_text, t2.value_numeric) test_result, rft.name reason_for_test,
          cohort_disaggregated_age_group(birthdate, '#{@end_date.to_date}') age_group")

          return results.map do |sample|
            {
              order_date: sample.start_date.to_date,
              result_date: sample.result_date.to_date,
              gender: sample.gender,
              birthdate: sample.birthdate,
              test: sample.test_name,
              age_group: sample.age_group,
              arv_number: sample.arv_number,
              reason_for_test: sample.reason_for_test,
              result: sample.test_result,
              value_modifier: sample.value_modifier,
              patient_id: sample.patient_id
            }
          end

        end

        def concept(name)
          ConceptName.find_by_name(name)
        end

      end
   end
  end
end
