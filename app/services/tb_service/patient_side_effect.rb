module TbService
  class PatientSideEffect
    include ModelUtils

    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date.to_date
    end

    def side_effects
      etype = encounter_type 'COMPLICATIONS'
      yes_concept = concept 'Yes'
      mw_side_effect_concept = concept 'Malawi TB side effects'
      results = {}

      data = Observation.joins('INNER JOIN obs t2 ON obs.obs_id = t2.obs_group_id
        INNER JOIN concept_name n ON n.concept_id = t2.concept_id
        INNER JOIN encounter e ON e.encounter_id = obs.encounter_id').\
        where('obs.concept_id = ? AND obs.person_id = ?
        AND obs.obs_datetime <= ? AND t2.value_coded = ?
        AND e.encounter_type = ?', mw_side_effect_concept.concept_id,
        patient.id, @date.strftime('%Y-%m-%d 23:59:59'), yes_concept.concept_id, etype.id).\
        group('n.concept_id, date(obs.obs_datetime)').\
        select('n.name, t2.concept_id, t2.obs_datetime')

      # data = Observation.joins(:concept, :encounter)
      #                   .where(concept: side_effects_concept,
      #                          person: patient,
      #                          obs_datetime: @date.strftime('%Y-%m-%d 23:59:59'),
      #                          value_coded: yes_concept,
      #                          encounter: { encounter_type: encounter})
      #                   .group(:concept_id, :obs_datetime)
      #                   .select([:concept_name, ])

      data.select do |r|
        obs_date    = r['obs_datetime'].to_date
        concept_id  = r['concept_id'].to_i
        results[obs_date] = {} if results[obs_date].blank?
        results[obs_date][concept_id] = {
          name: nil , drug_induced: false, drug: 'N/A'
        } if results[obs_date][concept_id].blank?

        results[obs_date][concept_id][:name] = r['name']
        drug_induced?(results[obs_date][concept_id], concept_id, obs_date)
      end

      return results
    end

    private

    def drug_induced?(e, concept_id, obs_date)
      drug_induced_concept = concept 'Drug induced'
      contraindication     = concept 'Contraindications'

      data = Observation.where('concept_id = ? AND person_id = ?
        AND value_coded = ? AND DATE(obs_datetime) = ?',
        drug_induced_concept.concept_id, @patient.id,
        concept_id, obs_date).last

      unless data.blank?
        drug_name = Drug.find(data.value_drug).name rescue data.value_text
        e[:drug_induced] = true
        e[:drug] = drug_name
      end

    end

  end
end
