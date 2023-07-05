# frozen_string_literal: true

class VmmcService::Reports::Cohort
  attr_reader :start_date, :end_date

  def initialize(start_date, end_date)
    @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
    @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
  end

	#AGE CATEGORY
  def neonates
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) <= 0 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def first_agegroup
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 0 AND (year(patient_program.date_created) - year(person.birthdate)) <= 14 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def second_agegroup
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 14 AND (year(patient_program.date_created) - year(person.birthdate)) <= 24 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def third_agegroup
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 24 AND (year(patient_program.date_created) - year(person.birthdate)) <= 49 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def fourth_agegroup
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 49 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def total_clients
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) >= 0 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  #HIV AND ART STATUS
  def positive_not_art
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9656 and value_coded = 703 AND obs.person_id IN (select person_id from obs where concept_id = 7010 and value_coded = 1066 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def positive_on_art
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9656 and value_coded = 703 AND obs.person_id IN (select person_id from obs where concept_id = 7010 and value_coded = 1065 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def negative
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1065 AND obs.person_id IN (select person_id from obs where concept_id = 2169 and value_coded = 664 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def positive
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1065 AND obs.person_id IN (select person_id from obs where concept_id = 2169 and value_coded = 703 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def testing_declined
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1066 AND obs.person_id IN (select person_id from obs where concept_id = 9569 and value_coded = 9601 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def testing_not_done
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1066 AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  # def eligible_clients
  #   ActiveRecord::Base.connection.select_one(
  #     <<~SQL
  #       SELECT COUNT(DISTINCT(encounter.patient_id)) AS total FROM encounter WHERE encounter.patient_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 39 AND encounter.voided = 0 AND (encounter.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
  #     SQL
  #   )['total']
  # end

  #Circumcision status
  def circumcision_full
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 9582 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def circumcision_partial
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 8512 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def circumcision_none
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 1107 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  #Contraindications status
  def contraindications_none
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 and value_coded = 1066 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def contraindications_yes
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 and value_coded = 1065 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def contraindications_total
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  #Consent status
  def yes_consent
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.value_coded = 1065 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def no_consent
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.value_coded = 1066 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def total_consent
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  #procedures used
  def forceps_guided
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 9608 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def device
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 9610 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  def others
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 6408 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def none
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9590 and value_coded = 1107 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def mild
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9590 and value_coded = 1901 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def moderate
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9590 and value_coded = 1900 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def severe
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9590 and value_coded = 1903 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def first_review_within_48_hours
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(t1.person_id)) AS total FROM obs t1 LEFT OUTER JOIN obs t2 ON t1.person_id = t2.person_id AND t1.voided = 0 AND t2.voided = 0 WHERE t1.concept_id = 9583 AND t2.concept_id = 9592 AND t1.voided = 0 AND t2.voided = 0 AND timestampdiff(hour, t1.obs_datetime, t2.obs_datetime) >= 0 AND timestampdiff(hour, t1.obs_datetime, t2.obs_datetime) <= 48 AND (t1.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def first_review_after_48_hours
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(t1.person_id)) AS total FROM obs t1 LEFT OUTER JOIN obs t2 ON t1.person_id = t2.person_id AND t1.voided = 0 AND t2.voided = 0 WHERE t1.concept_id = 9583 AND t2.concept_id = 9592 AND t1.voided = 0 AND t2.voided = 0 AND timestampdiff(hour, t1.obs_datetime, t2.obs_datetime) > 48 AND (t1.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
  
  def postop_none
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 159 AND obs.concept_id = 1643 and value_coded = 1107 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def postop_mild
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 159 AND obs.concept_id = 1643 and value_coded = 1901 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def postop_moderate
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 159 AND obs.concept_id = 1643 and value_coded = 1900 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end

  def postop_severe
    ActiveRecord::Base.connection.select_one(
      <<~SQL
        SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 159 AND obs.concept_id = 1643 and value_coded = 1903 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
      SQL
    )['total']
  end
end
