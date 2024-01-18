# frozen_string_literal: true

module Api
  module V1
    class AncController < ApplicationController
      extend ModelUtils

      def deliveries
        date = begin
          params[:date].to_date
        rescue StandardError
          nil
        end

        raise 'Date is missing' if date.nil?

        encounter_type = EncounterType.find_by name: 'CURRENT PREGNANCY'
        concept = Concept.joins(:concept_names).where('concept_name.name = ?', 'Estimated date of delivery').first

        clients = ActiveRecord::Base.connection.select_all("SELECT
      i.identifier, p.birthdate, p.gender, n.given_name,
      n.family_name, obs.person_id, p.birthdate_estimated
      FROM obs
      INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      AND e.voided = 0 AND obs.voided = 0 AND e.program_id = 12
      AND e.encounter_type = #{encounter_type.id}
      RIGHT JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
      RIGHT JOIN person_address a ON a.person_id = e.patient_id AND a.voided = 0
      RIGHT JOIN person_name n ON n.person_id = e.patient_id AND n.voided = 0
      RIGHT JOIN patient_identifier i ON i.patient_id = e.patient_id AND i.voided = 0
      AND i.identifier_type IN(2,3)
      WHERE obs.concept_id = #{concept.concept_id}
      AND value_datetime BETWEEN '#{date.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{date.strftime('%Y-%m-%d 23:59:59')}'
      GROUP BY i.identifier, p.birthdate, p.gender,
      n.given_name, n.family_name,
      obs.person_id, p.birthdate_estimated;")

        clients_formatted = []
        already_counted = []

        (clients || []).each do |c|
          next if already_counted.include? c['person_id']

          already_counted << c['person_id']

          clients_formatted << {
            given_name: c['given_name'], family_name: c['family_name'],
            birthdate: c['birthdate'], gender: c['gender'], person_id: c['person_id'],
            npid: c['identifier'], birthdate_estimated: c['birthdate_estimated']
          }
        end

        render json: clients_formatted
      end

      def visits
        visits = {}
        visits[:incomplete] = 0
        visits[:complete] = 0

        date = begin
          params[:date].to_date
        rescue StandardError
          nil
        end

        raise 'Date is missing' if date.nil?

        find_visiting_patients(date).each do |patient|
          if workflow_engine(patient, date).next_encounter
            visits[:incomplete] += 1
          else
            visits[:complete] += 1
          end
        end

        render json: visits
      end

      # Returns a list of patients who visited the ANC clinic on given day.
      def find_visiting_patients(date)
        day_start, day_end = TimeUtils.day_bounds(date)
        Patient.find_by_sql(
          [
            'SELECT patient.* FROM patient INNER JOIN encounter USING (patient_id)
         WHERE encounter.encounter_datetime BETWEEN ? AND ?
          AND encounter.voided = 0 AND patient.voided = 0
         GROUP BY patient.patient_id',
            day_start, day_end
          ]
        )
      end

      def workflow_engine(patient, date)
        AncService::WorkflowEngine.new patient:,
                                       program: Program.find_by_name('ANC PROGRAM'),
                                       date:
      end

      def essentials
        patient = params[:patientent_id]
        date = params[:date]
        anc_service = AncService::PatientsEngine.new program: Program.find_by_name('ANC PROGRAM')
        render json: anc_service.essentials(patient, date)
      end
    end
  end
end
