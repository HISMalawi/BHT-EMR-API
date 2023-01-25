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
          ls = ['hiv_status', 'syphilis_status', 'hepb_status', 'recency', 'self_kits']
          d.rows.each_with_index do | rows, rindex |
            user_id = rows[0]
            rows.each_with_index do | value, vindex |
              if !users.has_key?(user_id)
                users[user_id] = {}
              end
              column = d.columns[vindex]
              if !users[user_id].has_key?(column)
                if ls.include?(column)
                  users[user_id][column] = []
                else
                  users[user_id][column] = value
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
          users
        end

        def fetch_data
          testing_encounter = encounter_type('Testing').encounter_type_id
          ActiveRecord::Base.connection.select_all <<~SQL
            select
              u.user_id,
              u.username,
              up.property_value as provider_code,
              p1.person_id AS hiv_status,
              p2.person_id AS syphilis_status,
              p3.person_id AS hepb_status,
              p4.person_id AS recency,
              p5.person_id  AS self_kits
            from users u
            inner join person p on p.person_id = u.person_id
            inner join encounter e on e.provider_id = p.person_id and e.voided = 0 and e.program_id = 18
            left join user_property up on up.user_id = u.user_id and up.property = 'hts_provider_code'
            left join obs p1 on p1.encounter_id = e.encounter_id and p1.voided = 0 and p1.concept_id = #{concept('HIV Status').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p2 on p2.encounter_id = e.encounter_id and p2.voided = 0 and p2.concept_id = #{concept('Syphilis Test Result').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p3 on p3.encounter_id = e.encounter_id and p3.voided = 0 and p3.concept_id = #{concept('Hepatitis B Test Result').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p4 on p4.encounter_id = e.encounter_id and p4.voided = 0 and p3.concept_id = #{concept('Recency Test').concept_id} and e.encounter_type = #{testing_encounter}
            left join obs p5 on p5.encounter_id = e.encounter_id and p5.voided = 0 and p5.concept_id = #{concept('Self-Test Kit').concept_id} and e.encounter_type = #{encounter_type('ITEMS GIVEN').encounter_type_id}
            where DATE(e.encounter_datetime) between '#{@start_date}' and '#{@end_date}'
          SQL
        end
      end
    end
  end
end