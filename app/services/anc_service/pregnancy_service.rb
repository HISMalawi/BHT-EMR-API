module ANCService
  module PregnancyService
    def self.date_of_pregnancy_end(patient, date)
      patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ? AND obs.value_coded = ?
          AND DATE(encounter_datetime) <= DATE(?)',
          EncounterType.find_by_name('PREGNANCY STATUS').encounter_type_id,
          ConceptName.find_by_name("Pregnancy status").concept_id,
          ConceptName.find_by(name: "New", concept_name_type: "FULLY_SPECIFIED").concept_id,
          date
        ]).order(encounter_datetime: :desc).first.encounter_datetime rescue '1905-01-01'
    end

    def self.date_of_lnmp(patient, date)
      lmp = ConceptName.find_by name: "Last menstrual period"
      current_pregnancy = EncounterType.find_by name: 'CURRENT PREGNANCY'
      patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ? AND DATE(obs.obs_datetime) >= DATE(?)',
          current_pregnancy.id, lmp.concept_id, date_of_pregnancy_end(patient, date)])
        .last.observations.collect {
          |o| o.value_datetime
        }.compact.last.to_date rescue nil
    end
  end
end