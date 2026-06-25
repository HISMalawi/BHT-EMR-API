namespace :vitals do
  VOID_REASON_PREFIX = "Wrongly entered height - replaced by obs"

  desc "Fixes wrongly entered height in multiple vitals observations"
  task fix_height: :environment do
    patient_id = ENV['PATIENT_ID']
    program_id = ENV['PROGRAM_ID'] || 1
    correct_height = ENV['HEIGHT']&.to_f
    dry_run = ENV['DRY_RUN']&.downcase == 'true'

    unless patient_id && program_id && correct_height&.positive?
      puts "Usage: rails vitals:fix_height PATIENT_ID=<id> [PROGRAM_ID=<id>] HEIGHT=<correct_height_cm> [DRY_RUN=true]"
      exit 1
    end

    encounter_type = EncounterType.find_by_name('VITALS')
    height_concept_id = ConceptName.find_by_name('Height (cm)').concept_id
    weight_concept_id = ConceptName.find_by_name('Weight (kg)').concept_id
    bmi_concept_id = ConceptName.find_by_name('BMI').concept_id

    encounters = Encounter.where(
      patient_id: patient_id,
      program_id: program_id,
      encounter_type: encounter_type.encounter_type_id
    )

    puts dry_run ? "=== DRY RUN MODE (no changes will be saved) ===" : "=== LIVE MODE ==="
    puts "Patient ID: #{patient_id}"
    puts "Program ID: #{program_id}"
    puts "Correct height: #{correct_height} cm"
    puts "Total vitals encounters found: #{encounters.count}"
    puts ""

    # Retrieve the earliest height observation for this patient
    person = Person.find(patient_id)
    earliest_height_obs = Observation.where(person_id: patient_id, concept_id: height_concept_id)
                                     .order(:obs_datetime)
                                     .first

    if earliest_height_obs
      obs_date = earliest_height_obs.obs_datetime.to_date
      age_at_capture = if person.birthdate
                         ((earliest_height_obs.obs_datetime.to_time - person.birthdate.to_time) / 1.year.seconds).floor
                       else
                         'unknown (no birthdate)'
                       end
      puts "=== Earliest Height Record ==="
      puts "Height: #{earliest_height_obs.value_numeric} cm"
      puts "Captured on: #{obs_date}"
      puts "Patient age at capture: #{age_at_capture}#{age_at_capture.is_a?(Integer) ? ' years' : ''}"
      puts ""
    else
      puts "No existing height observations found for this patient"
      puts ""
    end

    voided_height_count = 0
    voided_bmi_count = 0
    created_height_count = 0
    created_bmi_count = 0
    skipped_encounters = 0
    skipped_underage = 0

    ActiveRecord::Base.transaction do
      encounters.find_each do |encounter|
        height_obs = Observation.where(encounter_id: encounter.encounter_id, concept_id: height_concept_id)
        weight_obs = Observation.where(encounter_id: encounter.encounter_id, concept_id: weight_concept_id).first
        bmi_obs = Observation.where(encounter_id: encounter.encounter_id, concept_id: bmi_concept_id)

        if height_obs.blank? && bmi_obs.blank? && weight_obs.blank?
          skipped_encounters += 1
          next
        end
        age_at_encounter = -1
        # Skip encounters where patient was under 18 at the time of recording
        if person.birthdate
          age_at_encounter = ((encounter.encounter_datetime.to_time - person.birthdate.to_time) / 1.year.seconds).floor
          if age_at_encounter < 18
            skipped_underage += 1
            puts "  Skipping encounter ##{encounter.encounter_id} (#{encounter.encounter_datetime.strftime('%Y-%m-%d')}): patient was #{age_at_encounter} years old"
            next
          end
        end

        puts "Age #{age_at_encounter} at encounter"
        puts "Found height: #{height_obs.map(&:value_numeric).join(', ').presence || 'none'} cm, weight: #{weight_obs&.value_numeric || 'none'} kg, BMI: #{bmi_obs.map(&:value_numeric).join(', ').presence || 'none'} in encounter ##{encounter.encounter_id}"
        puts "--- Encounter ##{encounter.encounter_id} (#{encounter.encounter_datetime.strftime('%Y-%m-%d')}) ---"

        obs_datetime = encounter.encounter_datetime
        creator = User.current&.user_id || encounter.creator

        # Create/replace height obs if height was present
        if height_obs.present?
          new_height = Observation.create!(
            person_id: encounter.patient_id,
            encounter_id: encounter.encounter_id,
            concept_id: height_concept_id,
            value_numeric: correct_height,
            obs_datetime: obs_datetime,
            creator: creator
          )
          created_height_count += 1
          puts "  Created height obs ##{new_height.obs_id}: #{correct_height} cm"

          height_obs.each do |obs|
            puts "  Voiding height obs ##{obs.obs_id}: #{obs.value_numeric} cm -> replaced by ##{new_height.obs_id}"
            obs.void("#{VOID_REASON_PREFIX} ##{new_height.obs_id}")
            voided_height_count += 1
          end
        end

        # Recalculate BMI using correct_height if weight is available
        if weight_obs&.value_numeric&.positive? && correct_height.positive?
          bmi = (weight_obs.value_numeric / (correct_height * correct_height) * 10_000).round(1)
          new_bmi = Observation.create!(
            person_id: encounter.patient_id,
            encounter_id: encounter.encounter_id,
            concept_id: bmi_concept_id,
            value_numeric: bmi,
            obs_datetime: obs_datetime,
            creator: creator
          )
          created_bmi_count += 1
          puts "  Created BMI obs ##{new_bmi.obs_id}: #{bmi} (weight: #{weight_obs.value_numeric} kg)"

          bmi_obs.each do |obs|
            puts "  Voiding BMI obs ##{obs.obs_id}: #{obs.value_numeric} -> replaced by ##{new_bmi.obs_id}"
            obs.void("#{VOID_REASON_PREFIX} ##{new_bmi.obs_id}")
            voided_bmi_count += 1
          end
        else
          bmi_obs.each do |obs|
            puts "  Voiding BMI obs ##{obs.obs_id}: #{obs.value_numeric} (no valid weight to recalculate)"
            obs.void("#{VOID_REASON_PREFIX} - no weight available")
            voided_bmi_count += 1
          end
          puts "  Skipped BMI creation: no valid weight found for this encounter"
        end
      end

      raise ActiveRecord::Rollback if dry_run
    end

    puts ""
    puts "=== Summary ==="
    puts "Mode: #{dry_run ? 'DRY RUN (all changes rolled back)' : 'LIVE'}"
    puts "Encounters processed: #{encounters.count - skipped_encounters - skipped_underage}"
    puts "Encounters skipped (no height/BMI): #{skipped_encounters}"
    puts "Encounters skipped (patient under 18): #{skipped_underage}"
    puts "Height observations voided: #{voided_height_count}"
    puts "BMI observations voided: #{voided_bmi_count}"
    puts "New height observations created: #{created_height_count}"
    puts "New BMI observations created: #{created_bmi_count}"
    puts "Correct height used: #{correct_height} cm"

    unless dry_run
      puts ""
      puts "To reverse these changes, run:"
      puts "  rails vitals:reverse_fix_height PATIENT_ID=#{patient_id}"
    end
  end

  desc "Reverses a previous fix_height operation by reading void_reason references"
  task reverse_fix_height: :environment do
    patient_id = ENV['PATIENT_ID']

    unless patient_id
      puts "Usage: rails vitals:reverse_fix_height PATIENT_ID=<id>"
      exit 1
    end

    # Find all voided obs for this patient whose void_reason references a replacement obs
    voided_obs = Observation.unscoped
                            .where(person_id: patient_id, voided: 1)
                            .where("void_reason LIKE ?", "#{VOID_REASON_PREFIX}%")

    if voided_obs.empty?
      puts "No fix_height changes found for patient #{patient_id}"
      exit 0
    end

    # Extract replacement obs IDs from void_reason
    replacement_obs_ids = voided_obs.filter_map do |obs|
      obs.void_reason.match(/#(\d+)/)&.captures&.first&.to_i
    end.uniq

    puts "=== Reversing fix_height for patient #{patient_id} ==="
    puts "Found #{voided_obs.count} voided observations to restore"
    puts "Found #{replacement_obs_ids.count} replacement observations to void"
    puts ""

    restored_count = 0

    ActiveRecord::Base.transaction do
      # Void the replacement obs
      if replacement_obs_ids.present?
        Observation.where(obs_id: replacement_obs_ids).each do |obs|
          puts "  Voiding replacement obs ##{obs.obs_id} (value: #{obs.value_numeric})"
          obs.void("Reversed fix_height operation")
        end
      end

      # Restore originally voided obs
      voided_obs.each do |obs|
        puts "  Restoring original obs ##{obs.obs_id} (value: #{obs.value_numeric})"
      end
      restored_count = voided_obs.update_all(voided: 0, void_reason: nil, voided_by: nil, date_voided: nil)
    end

    puts ""
    puts "=== Reversal complete ==="
    puts "Restored #{restored_count} original observations"
    puts "Voided #{replacement_obs_ids.count} replacement observations"
  end
end
