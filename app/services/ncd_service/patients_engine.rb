# frozen_string_literal: true

class NCDService::PatientsEngine
  include ModelUtils
  def initialize(program:)
    @program = program
  end

  def visit_summary_label(patient, date)
    OPDService::VisitLabel.new(patient, date)
  end
  # Retrieves given patient's status info.
  #
  # The info is just what you would get on a patient information
  # confirmation page in an ART application.
  def patient(patient_id, date)
    patient_summary(Patient.find(patient_id), date).full_summary
  end

  def patient_summary(patient, date)
    PatientSummary.new patient, date
  end

   def find_next_available_ncd_number
      current_ncd_code = global_property('site_prefix')&.property_value
      raise 'Global property `site_prefix` not set' unless current_ncd_code

      type = PatientIdentifierType.find_by_name('NCD Number')
      current_ncd_number_identifiers = PatientIdentifier.where(identifier_type: type)

      unless current_ncd_number_identifiers.nil?
        assigned_ncd_ids = current_ncd_number_identifiers.collect do |identifier|
          Regexp.last_match(1).to_i if identifier.identifier =~ /#{current_ncd_code}-NCD- *(\d+)/
        end.compact
      end

      next_available_number = nil

      if assigned_ncd_ids.empty?
        next_available_number = 1
      else
        assigned_numbers = assigned_ncd_ids.sort

        possible_number_range = global_property('ncd_number_range')&.property_value&.to_i || 100_000

        possible_identifiers = Array.new(possible_number_range) { |i| (i + 1) }
        next_available_number = (possible_identifiers - assigned_numbers).first
      end   

      "#{current_ncd_code} #{next_available_number}"
    end

    def ncd_number_already_exists(ncd_number)
      identifier_type = PatientIdentifierType.find_by_name('NCD Number')
      identifiers = PatientIdentifier.all.where(
        identifier: ncd_number,
        identifier_type: identifier_type.id
      ).exists?
    end

end
