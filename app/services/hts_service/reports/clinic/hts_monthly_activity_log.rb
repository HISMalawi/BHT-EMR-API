# frozen_string_literal: true

include ModelUtils

module HtsService
  module Reports
    module Clinic
      class HtsMonthlyActivityLog
        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def data
          users = {}
          d = fetch_data
          ls = %w[hiv_status syphilis_status hepb_status recency]
          d.rows.each_with_index do |rows, _rindex|
            user_id = rows[0]
            person_id = rows[1]
            unless users.key?(user_id)
              users[user_id] = {}
              users[user_id]['self_test_kits'] = self_test_kits(person_id)
            end
            rows.each_with_index do |value, vindex|
              column = d.columns[vindex]
              unless users[user_id].key?(column)
                users[user_id][column] = if ls.include?(column)
                                           []
                                         else
                                           value
                                         end
              end

              next if value.nil?

              if ls.include?(column)
                users[user_id][column] << value
              else
                users[user_id][column] = value
              end
            end
          end
          users.values
        end

        def self_test_kits(provider_id)
          ActiveRecord::Base.connection.select_all <<~SQL
            select
              o.person_id,
              o.value_numeric as self_kits
            from encounter e
            inner join obs o on o.encounter_id = e.encounter_id
            where o.voided = 0 and o.concept_id = #{concept('Self-Test Kit').concept_id}
            and e.program_id = 18 and e.encounter_type = #{encounter_type('ITEMS GIVEN').encounter_type_id}
            and DATE(e.encounter_datetime) between "#{@start_date}" and "#{@end_date}"
            and e.provider_id = #{provider_id}
            and o.value_numeric > 0
            group by o.person_id
          SQL
        end

        def fetch_data
          testing_encounter = encounter_type('Testing').encounter_type_id
          ActiveRecord::Base.connection.select_all <<~SQL
            select
              u.user_id,
              u.person_id AS user_person,
              u.username,
              up.property_value as provider_code,
              p1.person_id AS hiv_status,
              p2.person_id AS syphilis_status,
              p3.person_id AS hepb_status,
              p4.person_id AS recency
            from users u
            inner join person p on p.person_id = u.person_id
            inner join encounter e on e.provider_id = p.person_id and e.voided = 0 and e.program_id = 18
            left join user_property up on up.user_id = u.user_id and up.property = 'hts_provider_code'
            left join obs p1 on p1.encounter_id = e.encounter_id and p1.voided = 0 and p1.concept_id = #{concept('HIV Status').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p2 on p2.encounter_id = e.encounter_id and p2.voided = 0 and p2.concept_id = #{concept('Syphilis Test Result').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p3 on p3.encounter_id = e.encounter_id and p3.voided = 0 and p3.concept_id = #{concept('Hepatitis B Test Result').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p4 on p4.encounter_id = e.encounter_id and p4.voided = 0 and p4.concept_id = #{concept('Recency Test').concept_id} and e.encounter_type = #{testing_encounter}
            where DATE(e.encounter_datetime) between '#{@start_date}' and '#{@end_date}'
            GROUP BY p1.person_id,p2.person_id,p3.person_id,p4.person_id
          SQL
        end
      end
    end
  end
end
