# frozen_string_literal: true

module PatientRegistrationService
  module Reports
    module Clinic
      # This class is used to generate the overview report for the clinic.
      class OverviewReport
        SERVICES = ['Casualty', 'Dental', 'Eye', 'Family Planing', 'Medical', 'OB/Gyn', 'Orthopedics',
                    'Pediatrics', 'Skin', 'STI Clinic', 'Surgical', 'Other'].freeze

        def initialize(date = Date.today)
          @start_date = date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          report_two
        end

        private

        def report
          result = {}
          SERVICES.each do |service|
            result[service] =
              { total: total_patients_by_service(service)['total'].to_i,
                me: total_patients_by_service(service, User.current.id)['total'].to_i }
          end
          result['Newly Registered Patients'] =
            { total: newly_registered_patients['total'].to_i,
              me: newly_registered_patients(User.current.id)['total'].to_i }
          total = total_recorded['total'].to_i
          me_total = total_recorded(User.current.id)['total'].to_i
          result['Returning Patients'] =
            { total: total - result['Newly Registered Patients'][:total],
              me: me_total - result['Newly Registered Patients'][:me] }
          result
        end

        def report_two
          result = {}
          clinic = total_patients_by_service
          me = total_patients_by_service(User.current.id)
          SERVICES.each do |service|
            total_object = clinic&.find { |k| k['value_text'] == service }
            total = total_object ? total_object['total'].to_i : 0
            me_object = me&.find { |k| k['value_text'] == service }
            me_total = me_object ? me_object['total'].to_i : 0
            result[service] = { total: total, me: me_total }
          end
          result['Newly Registered Patients'] =
            { total: newly_registered_patients['total'].to_i,
              me: newly_registered_patients(User.current.id)['total'].to_i }
          total = total_recorded['total'].to_i
          me_total = total_recorded(User.current.id)['total'].to_i
          result['Returning Patients'] =
            { total: total - result['Newly Registered Patients'][:total],
              me: me_total - result['Newly Registered Patients'][:me] }
          result
        end

        def total_patients_by_service(user_id = nil)
          concept_id = ConceptName.find_by_name('Services ordered').concept_id
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.value_text, count(*) AS total FROM obs o
            WHERE o.concept_id = #{concept_id}
            #{user_id.nil? ? '' : "AND o.creator = #{user_id}"}
            AND o.value_text IN ('Casualty', 'Dental', 'Eye', 'Family Planing', 'Medical', 'OB/Gyn', 'Orthopedics','Pediatrics', 'Skin', 'STI Clinic', 'Surgical', 'Other')
            AND o.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND o.voided = 0
            GROUP BY o.value_text
          SQL
        end

        def newly_registered_patients(user_id = nil)
          ActiveRecord::Base.connection.select_one <<~SQL
            SELECT count(DISTINCT(e.patient_id)) AS total
            FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Type of patient').concept_id} AND o.value_coded = #{ConceptName.find_by_name('New Patient').concept_id}
            WHERE e.encounter_type = #{EncounterType.find_by_name('Registration').id}
            #{user_id.nil? ? '' : "AND e.creator = #{user_id}"}
            AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND e.program_id = #{Program.find_by_name('PATIENT REGISTRATION PROGRAM').id}
          SQL
        end

        def total_recorded(user_id = nil)
          ActiveRecord::Base.connection.select_one <<~SQL
            SELECT count(DISTINCT(e.patient_id)) AS total
            FROM encounter e
            WHERE e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            #{user_id.nil? ? '' : "AND e.creator = #{user_id}"}
            AND e.program_id = #{Program.find_by_name('PATIENT REGISTRATION PROGRAM').id}
          SQL
        end
      end
    end
  end
end
