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
      lmp_concept = ConceptName.find_by name: "Last menstrual period"
      current_pregnancy = EncounterType.find_by name: 'CURRENT PREGNANCY'
      lmp_obs = Observation.joins(:encounter).select('value_datetime')
        .where(concept: lmp_concept,
              person: patient.person,
              encounter: { encounter_type: current_pregnancy.encounter_type_id })
        .where('concept_id = ? AND DATE(obs_datetime) >= DATE(?)',
          lmp_concept.concept_id, date_of_pregnancy_end(patient, date)
        ).last
      return lmp_obs.value_datetime.to_date if !lmp_obs.blank?
    end
  end
end
