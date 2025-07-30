# rubocop:disable Metrics/MethodLength
# frozen_string_literal: true

def patients
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT ob.person_id, count(ob.person_id) dup_lmp_count, min(ob.obs_datetime) latest_preg_min_lmp_date
    FROM obs ob
      INNER JOIN(
        SELECT MAX(ob2.obs_datetime) start_date, ob2.person_id
        FROM obs ob2
          INNER JOIN encounter ON ob2.encounter_id = encounter.encounter_id
          AND encounter.encounter_type = #{EncounterType.find_by_name('ANC VISIT TYPE').id}
          AND encounter.voided = 0
        AND ob2.concept_id = #{Concept.find_by_name('Reason for visit').id}
        AND ob2.value_numeric = 1 /*First visit for a new preganancy*/
        AND ob2.voided = 0
        GROUP BY person_id
      ) as latest_preg_visit1 ON latest_preg_visit1.person_id = ob.person_id
      INNER JOIN encounter ON ob.encounter_id = encounter.encounter_id
      AND encounter.voided = 0
      AND encounter.program_id = #{Program.find_by_name('ANC PROGRAM').id}
    WHERE ob.obs_datetime > IF(latest_preg_visit1.start_date, latest_preg_visit1.start_date, DATE("1901-01-01 00:00:00"))
    AND ob.voided = 0
    AND ob.concept_id = #{Concept.find_by_name('Date of last menstrual period').id}
    AND ob.value_datetime IS NOT NULL
    AND encounter_datetime >= '2023-10-01' /*this is the point it all started to go wrong and also previous data do not have the new pregancy encounter*/
    GROUP BY ob.person_id
    HAVING dup_lmp_count > 1
  SQL
end

def delete_duplicate_lmp(patient)
  patient_id = patient['person_id']
  first_lmp = patient['latest_preg_min_lmp_date']

  Encounter.where(
    program_id: Program.find_by_name('ANC PROGRAM').id,
    encounter_type: EncounterType.find_by_name('CURRENT PREGNANCY').id,
    patient_id:
  ).where('encounter_datetime > ?', first_lmp).each do |encounter|
    encounter.void("Duplicate LMP Recorded for same Pregnancy (#{first_lmp})")
  end
end

puts "Found #{patients.length} patients with duplicate LMPs, cleaning data..."

ActiveRecord::Base.transaction do
  patients.each(&method(:delete_duplicate_lmp))
end

puts 'Done!'

# rubocop:enable Metrics/MethodLength
