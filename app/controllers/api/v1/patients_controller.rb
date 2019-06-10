# frozen_string_literal: true

require 'securerandom'
require 'dde_client'
require 'person_service'
require 'zebra_printer/init'

class Api::V1::PatientsController < ApplicationController
  # TODO: Refactor the business logic here into a service class

  before_action :authenticate, except: %i[print_national_health_id_label print_filing_number]

  include ModelUtils

  def show
    render json: patient
  end

  def search_by_npid
    render json: service.find_patients_by_npid(params.require(:npid))
  end

  def search_by_identifier
    identifier_type_id, identifier = params.require(%i[type_id identifier])
    identifier_type = PatientIdentifierType.find(identifier_type_id)
    render json: service.find_patients_by_identifier(identifier, identifier_type)
  end

  # GET /api/v1/search/patients
  def search_by_name_and_gender
    given_name, family_name, gender = params.require(%i[given_name family_name gender])
    render json: service.find_patients_by_name_and_gender(given_name, family_name, gender)
  end

  def create
    person = Person.find(params.require(:person_id))
    program = Program.find(params.require(:program_id))

    render json: service.create_patient(program, person), status: :created
  end

  def update
    render json: service.update_patient(patient, params.require(:person_id))
  end

  def print_national_health_id_label
    patient = Patient.find(params[:patient_id])

    label = generate_national_id_label patient
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
    render json: service.find_patient_visit_dates(patient, program)
  end

  def find_median_weight_and_height
    weight, height = service.find_patient_median_weight_and_height(patient)
    render json: { weight: weight, height: height }
  end

  def drugs_received
    cut_off_date = params[:date]&.to_date || Date.today
    drugs_orders = paginate(service.drugs_orders(patient, cut_off_date))

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

  def assign_tb_number(date)
    patient_id = params[:patient_id]
    tb_number = service.assign_tb_number(patient_id, date)
    render json: tb_number, status: :created
  end

  def get_tb_number
    patient_id = params[:patient_id]
    tb_number = service.get_tb_number(patient_id)
    if tb_number
      render json: tb_number, status: :ok
    else
      render :status => 404
    end
  end

  def assign_npid
    render json: service.assign_npid(patient), status: :created
  end

  def find_archiving_candidates
    page = params[:page]&.to_i || 0
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
    render json: service.patient_last_drugs_received(patient, date, program_id)
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

  private

  def patient
    Patient.find(params[:id] || params[:patient_id])
  end

  def generate_national_id_label(patient)
    person = patient.person

    national_id = patient.national_id
    return nil unless national_id

    sex =  "(#{person.gender})"
    address = person.addresses.first.to_s.strip[0..24].humanize
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, national_id)
    label.draw_multi_text(person.name.titleize)
    label.draw_multi_text("#{patient.national_id_with_dashes} #{person.birthdate}#{sex}")
    label.draw_multi_text(address)
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
    number = number[len..len] + '   ' + number[(len + 1)..(len + 2)] + ' ' + number[(len + 3)..(number.length)]

    label = ZebraPrinter::StandardLabel.new
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
    number = file[5..-1]

    number = number[0..1] + ' ' + number[2..3] + ' ' + number[4..-1]

    label = ZebraPrinter::StandardLabel.new
    label.draw_text(number, 75, 30, 0, 4, 4, 4, false)
    label.draw_text("Filing area #{file_type}", 75, 150, 0, 2, 2, 2, false)
    label.draw_text("Version number: #{version_number}", 75, 200, 0, 2, 2, 2, false)
    label.print(num)
  end

  def service
    @service ||= PatientService.new
  end

  def filing_number_service
    @filing_number_service ||= FilingNumberService.new
  end

  def person_service
    PersonService.new
  end
end
