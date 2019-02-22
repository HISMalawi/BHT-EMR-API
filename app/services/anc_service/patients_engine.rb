# frozen_string_literal: true

module ANCService
  # Patients sub service.
  #
  # Basically provides ANC specific patient-centric functionality
  class PatientsEngine
    include ModelUtils

    ART_PROGRAM =  Program.find_by name: 'HIV PROGRAM'
    ARV_NUMBER = PatientIdentifierType.find_by name: 'ARV Number'
  
    def initialize(program:)
      @program = program
    end
  
    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an ANC application.
    def patient(patient_id, date)
      patient_summary(Patient.find(patient_id), date).full_summary
    end

    def visit_summary_label(patient, date)
      ANCService::PatientVisitLabel.new patient, date
    end

    def anc_visit(patient, date)
      last_lmp = patient.encounters.joins([:observations])
                  .where(['encounter_type = ? AND obs.concept_id = ?',
                    EncounterType.find_by_name('Current pregnancy').id,
                    ConceptName.find_by_name('Last menstrual period').concept_id])
                  .last.observations.collect { 
                    |o| o.value_datetime 
                }.compact.last.to_date #rescue nil

      return [] if last_lmp.blank?

      patient.encounters.where(["DATE(encounter_datetime) >= ? 
        AND DATE(encounter_datetime) <= ? AND encounter_type = ?",
        last_lmp, date,EncounterType.find_by_name("ANC VISIT TYPE")]).collect{|e|
          e.observations.collect{|o|
            o.answer_string.to_i if o.concept.concept_names.first.name.downcase == "reason for visit"
            }.compact
        }.flatten rescue []

    end

    def art_hiv_status(patient)

      hiv_positive = PatientProgram.find_by_sql("SELECT pg.patient_id 
        FROM patient_program pg
        WHERE pg.patient_id = #{patient.patient_id} 
        AND pg.program_id = #{ART_PROGRAM.id}")

      if !hiv_positive.blank?
        hiv_status = 'Positive'
        query = "SELECT pg.date_enrolled, s2.start_date, s2.state  
            FROM patient_program
            INNER JOIN patient_state s2 ON s2.patient_state_id = s2.patient_state_id 
						AND pg.patient_program_id = s2.patient_program_id
						AND s2.patient_state_id = (
              SELECT MAX(s3.patient_state_id) FROM patient_state s3
							WHERE s3.patient_state_id = s2.patient_state_id)
            AND pg.voided = 0 AND pg.patient_id = '#{patient.patient_id}' 
            AND s2.state = 7 ORDER BY s2.start_date ASC LIMIT 1"

				art_start_date = PatientProgram.find_by_sql(query).first.date_enrolled.to_date.to_s(:db) rescue nil

        on_art = 'Yes' if art_start_date.present?

        if (on_art.downcase == 'yes')

          arv_number = PatientIdentifier.find_by_sql("SELECT pi.identifier 
            FROM patient_identifier pi
            WHERE pi.identifier_type = #{ARV_NUMBER.id} 
              AND pi.patient_id = '#{patient.patient_id}'
            ORDER BY pi.date_created DESC LIMIT 1")[0]['identifier']

        end rescue nil

      end

      return {hiv_status: hiv_status, art_status: on_art, arv_number: arv_number, arv_start_date: art_start_date}

    end

    private

    def patient_summary(patient, date)
      PatientSummary.new patient, date
    end
    
  end

end
