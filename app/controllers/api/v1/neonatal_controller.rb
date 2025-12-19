# frozen_string_literal: true

module Api
  module V1
    class NeonatalController < ApplicationController
      include ModelUtils

      def statistics
        date = parse_date(params[:date])

        stats = patients_engine.statistics(date)

        render json: stats
      end

      def visit_summary
        date = parse_date(params[:date]) || Date.today

        visits = {
          date: date,
          total_visits: find_visiting_patients(date).count
        }

        render json: visits
      end

      def saved_encounters
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)
        date = parse_date(params[:date])

        encounters = patients_engine.saved_encounters(patient, date)

        render json: { encounters: encounters }
      end

      private

      
      def neonatal_program
        @neonatal_program ||= Program.find_by_name('NEONATAL PROGRAM') ||
                              Program.find_by_name('Neonatal program')
      end

      def enrollment_engine(patient)
        NeonatalService::EnrollmentEngine.new(
          patient: patient,
          program: neonatal_program,
          date: parse_date(params[:date])
        )
      end

      def patients_engine
        @patients_engine ||= NeonatalService::PatientsEngine.new(program: neonatal_program)
      end

    

      def find_visiting_patients(date)
        day_start, day_end = TimeUtils.day_bounds(date)

        Patient.joins(:encounters)
               .where('encounter.program_id = ?', neonatal_program.program_id)
               .where('encounter.encounter_datetime BETWEEN ? AND ?', day_start, day_end)
               .where('encounter.voided = 0')
               .where('patient.voided = 0')
               .distinct
      end
    end
  end
end
