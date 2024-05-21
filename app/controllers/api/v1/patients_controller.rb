# frozen_string_literal: true

require 'securerandom'
require 'dde_client'
require 'person_service'
require 'zebra_printer/init'

module Api
  module V1
    class PatientsController < ApplicationController
      # TODO: Refactor the business logic here into a service class

      before_action :authenticate,
                    except: %i[print_national_health_id_label print_filing_number print_tb_number
                               print_tb_lab_order_summary print_hts_linkage_code]

      include ModelUtils

      def show
        render json: patient
      end

      def search_by_npid
        voided = params[:voided]&.casecmp?('true') || false
        render json: paginate(service.find_patients_by_npid(params.require(:npid), voided:))
      end

      def search_by_identifier
        identifier_type_id, identifier = params.require(%i[type_id identifier])
        voided = params[:voided]&.casecmp?('true') || false
        identifier_type = if voided
                            PatientIdentifierType.where(name: ['National id',
                                                               'Old identification number'])
                          else
                            PatientIdentifierType.find(identifier_type_id)
                          end

        render json: service.find_patients_by_identifier(identifier, identifier_type, voided:)
      end

      # GET /api/v1/search/patients
      def search_by_name_and_gender
        filters = params.permit(%i[given_name middle_name family_name birthdate gender])

        patients = service.find_patients_by_name_and_gender(filters[:given_name],
                                                            filters[:middle_name],
                                                            filters[:family_name],
                                                            filters[:gender])

        render json: patients
      end

      def create
        person = Person.find(params.require(:person_id))
        program = Program.find(params.require(:program_id))
        malawi_national_id = params[:malawi_national_ID]

        render json: service.create_patient(program, person, malawi_national_id), status: :created
      end

      def update
        render json: service.update_patient(patient, params.require(:person_id))
      end

      def destroy
        service.void_patient(patient, params.require(:reason), daemonize: false)

        render status: :no_content
      end

      def print_national_health_id_label
        patient = Patient.find(params[:patient_id])
        qr_code = if params[:qr_code]
                    params[:qr_code].casecmp?('true') ? true : false
                  else
                    false
                  end

        label = generate_national_id_label(patient, qr_code)
        send_data label, type: 'application/label;charset=utf-8',
                         stream: false,
                         filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                         disposition: 'inline',
                         refresh: "1; url=#{params[:redirect_to]}"
      end

      def print_filing_number
        archived = params[:archived]&.downcase == 'true'

        label_commands = if archived
                           generate_archived_filing_number_label(patient)
                         else
                           generate_filing_number_label(patient)
                         end

        send_data label_commands, type: 'application/label; charset=utf-8',
                                  stream: false,
                                  filename: "#{patient.id}#{rand(10_000)}.lbl",
                                  disposition: 'inline'
      end

      def visits
        program = params[:program_id] ? Program.find(params[:program_id]) : nil
        date = params[:date]&.to_date
        render json: service.find_patient_visit_dates(patient, program,
                                                      params[:include_defaulter_dates] == 'true', date)
      end

      def find_median_weight_and_height
        weight, height = service.find_patient_median_weight_and_height(patient)
        render json: { weight:, height: }
      end

      def drugs_received
        cut_off_date = params[:date]&.to_date || Date.today
        program_id = params[:program_id] || Program.first.id
        drugs_orders = paginate(service.drugs_orders_by_program(patient, cut_off_date, program_id:))

        render json: drugs_orders
      end

      def bp_readings_trail
        render json: service.patient_bp_readings_trail(patient, Date.today)
      end

      def assign_filing_number
        filing_number = params[:filing_number]
        response = service.assign_patient_filing_number(patient, filing_number)
        if response
          render json: response, status: :created
        else
          render status: :no_content
        end
      end

      def assign_national_identifier
        patient_id = params[:patient_id]
        date = params[:date] || Date.today
        number = params[:number]

        begin
          number = TbNumberService.assign_national_id(patient_id, date, number)
          render json: number, status: :created
        rescue TbNumberService::DuplicateIdentifierError
          render status: :conflict
        end
      end

      def update_national_identifier
        patient_id = params[:patient_id]
        date = params[:date] || Date.today
        number = params[:number]

        begin
          number = TbNumberService.update_national_id(patient_id, date, number)
          render json: number, status: :created
        rescue TbNumberService::DuplicateIdentifierError
          render status: :conflict
        end
      end

      def most_recent_lab_order
        patient_id, program_id, date = params.require(%i[patient_id program_id date])
        render json: service.most_recent_lab_order(patient_id:,
                                                   program_id:, date:)
      end

      def tpt_status
        patient_id = params.require(:patient_id)
        date = params[:date]&.to_date || Date.today
        render json: tb_prevention_service.new(start_date: date, end_date: date, patient_id:).find_report
      end

      def assign_tb_number
        patient_id = params[:patient_id]
        date = params[:date] || Date.today
        number = params[:number]
        type = params[:id_type]

        begin
          number = TbNumberService.assign_tb_number(patient_id, date, number, type)
          render json: number, status: :created
        rescue TbNumberService::DuplicateIdentifierError
          render status: :conflict
        end
      end

      def assign_npid
        render json: service.assign_npid(patient, params['program_id']), status: :created
      end

      def find_archiving_candidates
        page = params[:page].to_i
        page_size = params[:page_size]&.to_i || DEFAULT_PAGE_SIZE
        patients = filing_number_service.find_archiving_candidates(page * page_size, page_size)
        render json: patients
      end

      def current_bp_drugs
        date = params[:date]&.to_date || Date.today
        render json: service.current_htn_drugs_summary(patient, date)
      end

      def last_bp_drugs
        date = params[:date]&.to_date || Date.today
        render json: service.last_htn_drugs_received_summary(patient, date)
      end

      # Returns all drugs received on last dispensation
      def last_drugs_received
        date = params[:date]&.to_date || Date.today
        program_id = params[:program_id]
        render json: service.patient_last_drugs_received(patient, date, program_id:)
      end

      def drugs_orders_by_program
        cut_off_date = params[:date]&.to_date || Date.today
        program_id = params[:program_id]
        drugs_orders = paginate(service.drugs_orders_by_program(patient, cut_off_date, program_id:))

        render json: drugs_orders
      end

      # Returns all lab orders made since a given date
      def recent_lab_orders
        patient_id, program_id = params.require(%i[patient_id program_id])
        reference_date = params[:reference_date]&.to_date || Date.today
        render json: service.recent_lab_orders(patient_id:,
                                               program_id:,
                                               reference_date:)
      end

      def remaining_bp_drugs
        pills, drug_id = params.require(%i[pills drug_id])
        date = params[:date]&.to_date || Date.today
        render json: service.update_remaining_bp_drugs(patient, date, Drug.find(drug_id), pills)
      end

      def eligible_for_htn_screening
        date = params[:date]&.to_time || Time.now
        render json: {
          eligible: service.patient_eligible_for_htn_screening(patient, date)
        }
      end

      def update_or_create_htn_state
        state, = params.require %i[state]
        date = params[:date]&.to_time || Time.now
        render json: { updated: service.update_or_create_htn_state(patient, state, date) }
      end

      def filing_number_history
        render json: service.filing_number_history(patient)
      end

      # Returns all drugs pill counts done on last visit
      def last_drugs_pill_count
        date = params[:date]&.to_date || Date.today
        program_id = params[:program_id]
        render json: service.patient_last_drugs_pill_count(patient, date, program_id:)
      end

      def print_tb_lab_order_summary
        label = lab_tests_engine.generate_lab_order_summary(tb_lab_order_params)
        send_data label, type: 'application/label;charset=utf-8',
                         stream: false,
                         filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                         disposition: 'inline'
      end

      def print_hts_linkage_code
        label = HtsService::HtsLinkageCode.new(params[:patient_id], params[:code]).print_linkage_code
        send_data label, type: 'application/label;charset=utf-8',
                         stream: false,
                         filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                         disposition: 'inline'
      end

      def print_tb_number
        label = TbNumberService.generate_tb_patient_id(params[:patient_id])
        send_data label, type: 'application/label;charset=utf-8',
                         stream: false,
                         filename: "#{params[:patient_id]}-#{SecureRandom.hex(12)}.lbl",
                         disposition: 'inline'
      end

      def visit
        program = params[:program_id] ? Program.find(params[:program_id]) : nil
        render json: service.fetch_full_visit(patient, program, params[:date])
      end

      def tpt_prescription_count
        program = params[:program_id] ? Program.find(params[:program_id]) : nil
        render json: service.tpt_prescription_count(patient, program, params[:date])
      end

      def last_cxca_screening_details
        cxca = CxcaService::PatientSummary.new(patient, params[:date].to_date)
        render json: cxca.last_screening_info
      end

      def sync_to_ait
        from_date = params.delete(:from_date)
        to_date = params.delete(:to_date)
        patient_id = params.delete(:patient_id)

        AitIntergrationJob.perform_later({ from_date:, to_date:, patient_id: })
        render json: { status: 'Enqueued ait sync' }, status: :ok
      end

      def oldest_hts_patient
        Patient.joins(:person, encounters: :program)
               .where(encounter: { encounter_type: EncounterType.find_by_name('testing') },
                      program: { name: Program.find_by_name('HTC program').name })
               .distinct.order(patient_id: :asc).first.id
      end

      def visits_after_last_outcome
        program_id = params[:program]
        date = params[:date]

        render json: service.find_patient_visits_dates_since_last_outcome(patient.patient_id, program_id, date)
      end

      def tb_negative_minor
        patient_id = params.require %i[patient_id]
        response = tb_patient_engine.tb_negative_minor(patient_id)
        if response
          render json: response, status: :ok
        else
          render status: :no_content
        end
      end

      private

      def patient
        Patient.find(params[:id] || params[:patient_id])
      end

      def generate_national_id_label(patient, qr_code)
        person = patient.person

        national_id = patient.national_id
        return nil unless national_id

        sex =  "(#{person.gender})"
        address = person.addresses.first.to_s.strip[0..24].humanize
        label = ZebraPrinter::Lib::StandardLabel.new
        label.font_size = 2
        label.font_horizontal_multiplier = 2
        label.font_vertical_multiplier = 2
        label.left_margin = 50
        if qr_code
          label.draw_qrcode(600, 60, "#{person.name}~#{national_id}~#{person.birthdate}~#{person.gender}~#{address}")
          label.draw_barcode(50, 160, 0, 1, 4, 12, 120, false, national_id)
          label.draw_text(person.name.titleize, 35, 5, 0, 1, 2, 2, false)
          label.draw_text(patient.national_id_with_dashes, 35, 35, 0, 1, 2, 2, false)
          label.draw_text("#{person.birthdate} #{sex}", 35, 75, 0, 1, 2, 2, false)
          label.draw_text(address, 35, 105, 0, 1, 2, 2, false)
        else
          label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, national_id)
          label.draw_multi_text(person.name.titleize)
          label.draw_multi_text("#{patient.national_id_with_dashes} #{person.birthdate}#{sex}")
          label.draw_multi_text(address)
        end
        label.print(1)
      end

      def generate_filing_number_label(patient, num = 1)
        identifier = patient.identifier('Filing number') || patient.identifier('Archived filing number')
        raise NotFoundError, "Filing number for patient #{patient.id} not found" unless identifier

        file = identifier.identifier
        file_type = file.strip[3..4]
        version_number = file.strip[2..2]
        number = file
        len = number.length - 5
        number = "#{number[len..len]}   #{number[(len + 1)..(len + 2)]} #{number[(len + 3)..(number.length)]}"

        label = ZebraPrinter::Lib::StandardLabel.new
        label.draw_text(number, 75, 30, 0, 4, 4, 4, false)
        label.draw_text("Filing area #{file_type}", 75, 150, 0, 2, 2, 2, false)
        label.draw_text("Version number: #{version_number}", 75, 200, 0, 2, 2, 2, false)
        label.print(num)
      end

      def generate_archived_filing_number_label(patient, num = 1)
        identifier = patient.identifier('Archived filing number')
        raise NotFoundError, "Archived filing number for patient #{patient.id} not found" unless identifier

        file = identifier.identifier
        file_type = file.strip[3..4]
        version_number = file.strip[2..2]
        number = file[5..]

        number = "#{number[0..1]} #{number[2..3]} #{number[4..]}"

        label = ZebraPrinter::Lib::StandardLabel.new
        label.draw_text(number, 75, 30, 0, 4, 4, 4, false)
        label.draw_text("Filing area #{file_type}", 75, 150, 0, 2, 2, 2, false)
        label.draw_text("Version number: #{version_number}", 75, 200, 0, 2, 2, 2, false)
        label.print(num)
      end

      def service
        PatientService.new
      end

      def filing_number_service
        @filing_number_service ||= FilingNumberService.new
      end

      def person_service
        PersonService.new
      end

      def tb_patient_engine
        program = Program.find_by(name: 'TB PROGRAM')
        TbService::PatientsEngine.new program:
      end

      def ait_intergration_service(patient_id)
        HtsService::AitIntergration::AitIntergrationService.new(patient_id)
      end

      def tb_prevention_service
        @tb_prevention_service ||= ArtService::Reports::Pepfar::TptStatus
      end

      def tb_lab_order_params
        {
          patient_id: params[:patient_id],
          date: params[:session_date],
          test_type: params[:test_type],
          specimen_type: params[:specimen_type],
          recommended_examination: params[:recommended_examination],
          target_lab: params[:target_lab],
          reason_for_examination: params[:reason_for_examination],
          previous_tb_patient: params[:previous_tb_patient]
        }
      end

      def lab_tests_engine
        program = Program.find_by(name: 'TB PROGRAM')
        TbService::LabTestsEngine.new program:
      end
    end
  end
end
