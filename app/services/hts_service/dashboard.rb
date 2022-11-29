# frozen_string_literal: true
# HTS Service
module HTSService
  # Dashbiard Class
  class Dashboard
    def self.total_registered(date)
      Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                 .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                 .joins("INNER JOIN encounter_type ON encounter.encounter_type = encounter_type.encounter_type_id")
                 .where(encounter: {program_id: 18 }, encounter_type: { name: 'Testing'}, concept_name: { name: "HIV Status" })
                 .where('DATE(obs_datetime) = ?', date)
                 .count
    end

    def self.total_enrolled_into_art(date)
      on_art_concept = 7010
      Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                 .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                 .joins("INNER JOIN encounter_type ON encounter.encounter_type = encounter_type.encounter_type_id")
                 .where(encounter: { program_id: 18 }, encounter_type: { name: 'ART_FOLLOWUP' },
                    obs: { value_coded: on_art_concept }, concept_name: { name: "Antiretroviral therapy referral"}
                  )
                 .where('DATE(obs_datetime) = ?', date)
                 .count
    end

    def self.total_tested_returning(date)
      Observation.joins("INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id")
                 .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id")
                 .joins("INNER JOIN encounter_type ON encounter.encounter_type = encounter_type.encounter_type_id")
                 .where(encounter: { program_id: 18 }, encounter_type: { name: 'APPOINTMENT' },
                    concept_name: { name: "Appointment date"}
                  )
                 .where('DATE(obs.value_datetime) = ? ', date)
                 .count
    end

    def self.daily_statistics(start_date)
      date = start_date.to_date
      {
        total_enrolled_into_art: self.total_enrolled_into_art(date),
        total_registered: self.total_registered(date),
        total_tested_returning: self.total_tested_returning(date)
      }
    end
  end
end
