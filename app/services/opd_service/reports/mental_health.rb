# frozen_string_literal: true

module OpdService
  module Reports
    class MentalHealth
      def find_report(start_date:, end_date:, **_extra_kwargs)
        mental_health(start_date, end_date)
      end

      def mental_health(start_date, end_date)
        concept_names = ['Chronic Organic Mental Disorder', 'Acute Organic Mental Disorder', 'Alcohol Use Mental Disorder',
                         'Drug Use Mental Disorder', 'Schizophrenia', 'Acute & Transient Psychotic Disorder', 'Schizo-affective disorder', 'Mood Affective Disorder (Manic)',
                         'Mood Affective Disorder (Bipolar)', 'Mood Affective Disorder (Depresion)', 'Anxiety disorder', 'Stress Reaction Adjustment Disorder',
                         'Dissociative Conversion Disorder', 'Somatoform Disorder', 'Puerperal Mental Disorder', 'Personality/Behaviour Disorder', 'Mental Retardation',
                         'Psychological mental disorder', 'Hyperkinetic Conduct Disorder', 'Diarrhea, cholera']

        type = EncounterType.find_by_name 'Outpatient diagnosis'
        Encounter.where("encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ?
      AND c.name IN(?)",
                        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
                        end_date.to_date.strftime('%Y-%m-%d 23:59:59'), type.id, concept_names)\
                 .joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
      INNER JOIN person p ON p.person_id = encounter.patient_id
      LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0
      LEFT JOIN person_attribute z ON z.person_id = encounter.patient_id AND z.person_attribute_type_id = 12
      RIGHT JOIN person_address a ON a.person_id = encounter.patient_id
      INNER JOIN concept_name c ON c.concept_id = obs.value_coded
      ')\
                 .group('obs.person_id,obs.value_coded,DATE(obs.obs_datetime)')\
                 .select("encounter.encounter_type,n.given_name, n.family_name, n.person_id, obs.value_coded, p.gender, c.concept_id,
      a.state_province district, a.township_division ta, a.city_village village, z.value,
      opd_disaggregated_age_group(p.birthdate,'#{end_date.to_date}') as age_group,c.name")
      end
    end
  end
end
