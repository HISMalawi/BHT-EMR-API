# frozen_string_literal: true

module Api
  module V1
    class NeonatalController < ApplicationController
      include ModelUtils
      def enroll
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)

        enrollment_data = {
          date_enrolled: parse_date(params[:date_enrolled]),
          location_id: params[:location_id],
          encounter_datetime: parse_datetime(params[:encounter_datetime]),
          observations: params[:observations]
        }

        patient_program = enrollment_engine(patient).enroll(enrollment_data)

        render json: {
          patient_program_id: patient_program.patient_program_id,
          patient_id: patient.patient_id,
          program_id: patient_program.program_id,
          date_enrolled: patient_program.date_enrolled,
          location_id: patient_program.location_id
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { error: e.message }, status: :bad_request
      end

      def enrolled
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)

        engine = enrollment_engine(patient)

        render json: {
          enrolled: engine.enrolled?,
          enrollment_data: engine.enrolled? ? engine.enrollment_data : nil
        }
      end

      def update_enrollment
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)

        updates = params.permit(:date_enrolled, :location_id, :outcome)

        patient_program = enrollment_engine(patient).update_enrollment(updates.to_h)

        render json: {
          patient_program_id: patient_program.patient_program_id,
          date_enrolled: patient_program.date_enrolled,
          location_id: patient_program.location_id
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :bad_request
      end
    
      def exit_program
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)

        exit_data = {
          date_completed: parse_date(params[:date_completed]),
          outcome: params[:outcome]
        }

        patient_program = enrollment_engine(patient).exit_program(exit_data)

        render json: {
          patient_program_id: patient_program.patient_program_id,
          date_completed: patient_program.date_completed,
          outcome: patient_program.outcome
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :bad_request
      end

      def patient
        patient_id = params.require(:patient_id)
        date = parse_date(params[:date])

        summary = patients_engine.patient(patient_id, date)

        render json: summary
      end 

      def saved_encounters
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)
        date = parse_date(params[:date])

        encounters = patients_engine.saved_encounters(patient, date)

        render json: { encounters: encounters }
      end

      def patient_labels
        patient_id = params.require(:patient_id)
        patient = Patient.find(patient_id)
        date = parse_date(params[:date])

        labels = patients_engine.patient_labels(patient, date)

        render json: { labels: labels }
      end

      def enrolled_patients
        filters = {
          date: parse_date(params[:date]),
          page: params[:page],
          per_page: params[:per_page]
        }.compact

        patients = patients_engine.enrolled_patients(filters)

        render json: patients.map { |pp|
          {
            patient_program_id: pp.patient_program_id,
            patient_id: pp.patient_id,
            date_enrolled: pp.date_enrolled,
            patient: patient_basic_info(pp.patient)
          }
        }
      end

      def search_patients
        search_params = params.permit(:name, :identifier, :date_enrolled).to_h

        patients = patients_engine.search_patients(search_params)

        render json: patients.map { |pp|
          {
            patient_program_id: pp.patient_program_id,
            patient_id: pp.patient_id,
            date_enrolled: pp.date_enrolled,
            patient: patient_basic_info(pp.patient)
          }
        }
      end

      def visits
        date = parse_date(params[:date]) || Date.today

        patients = patients_engine.patients_visited_on(date)

        visits_summary = {
          date: date,
          total_visits: patients.count,
          patients: []
        }

        patients.each do |patient|
          visits_summary[:patients] << {
            patient_id: patient.patient_id,
            patient: patient_basic_info(patient),
            encounters: patients_engine.saved_encounters(patient, date)
          }
        end

        render json: visits_summary
      end

      def appointments
        date = parse_date(params[:date]) || Date.today

        appointments = patients_engine.patients_with_appointments_on(date)

        render json: appointments.map { |appt|
          {
            patient_id: appt[:patient_id],
            patient: patient_basic_info(appt[:patient]),
            appointment_date: appt[:appointment_date],
            encounter_id: appt[:encounter_id]
          }
        }
      end

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

      def parse_date(date_param)
        return Date.today if date_param.nil?
        return date_param if date_param.is_a?(Date)

        Date.parse(date_param.to_s)
      rescue ArgumentError
        Date.today
      end

      def parse_datetime(datetime_param)
        return Time.now if datetime_param.nil?
        return datetime_param if datetime_param.is_a?(DateTime) || datetime_param.is_a?(Time)

        DateTime.parse(datetime_param.to_s)
      rescue ArgumentError
        Time.now
      end

      def patient_basic_info(patient)
        person = patient.person
        names = person.names.first

        {
          patient_id: patient.patient_id,
          given_name: names&.given_name,
          family_name: names&.family_name,
          gender: person.gender,
          birthdate: person.birthdate,
          birthdate_estimated: person.birthdate_estimated
        }
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
