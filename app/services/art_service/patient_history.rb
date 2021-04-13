# frozen_string_literal: true

module ARTService
  # Carries comprehensive historical information on a patient.
  #
  # Example:
  #   $ patient_history = PatientHistory.new(patient, Date.today)
  #   $ patient_history.first_line_drugs # Returns patient's first line drugs
  #   $ patient_history.current_regimen # Returns patient's current regimen
  #   $ patient_history.print # Generates label printer commands for printing the history.
  class PatientHistory < ARTService::PatientSummary
    # Outputs a label with patient's history
    def print
      # demographics = mastercard_demographics(patient)

      label = ZebraPrinter::StandardLabel.new
      label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      label.draw_text(arv_number || 'N/A', 575, 30, 0, 3, 1, 1, false)
      label.draw_text('PATIENT DETAILS', 25, 30, 0, 3, 1, 1, false)
      label.draw_text("Name:   #{name} (#{sex})", 25, 60, 0, 3, 1, 1, false)
      label.draw_text("DOB:    #{birthdate}", 25, 90, 0, 3, 1, 1, false)
      label.draw_text("Phone: #{phone_number}", 25, 120, 0, 3, 1, 1, false)
      if (address.blank? ? 0 : address.length) > 48
        label.draw_text("Addr:  #{address[0..47]}", 25, 150, 0, 3, 1, 1, false)
        label.draw_text("    :  #{address[48..-1]}", 25, 180, 0, 3, 1, 1, false)
        last_line = 180
      else
        label.draw_text("Addr:  #{address}", 25, 150, 0, 3, 1, 1, false)
        last_line = 150
      end

      if !guardian.nil?
        if last_line == 180 && guardian.length < 48
          label.draw_text("Guard: #{guardian}", 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 180 && guardian.length > 48
          label.draw_text("Guard: #{guardian[0..47]}", 25, 210, 0, 3, 1, 1, false)
          label.draw_text("     : #{guardian[48..-1]}", 25, 240, 0, 3, 1, 1, false)
          last_line = 240
        elsif last_line == 150 && guardian.length > 48
          label.draw_text("Guard: #{guardian[0..47]}", 25, 180, 0, 3, 1, 1, false)
          label.draw_text("     : #{guardian[48..-1]}", 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 150 && guardian.length < 48
          label.draw_text("Guard: #{guardian}", 25, 180, 0, 3, 1, 1, false)
          last_line = 180
        end
      else
        if last_line == 180
          label.draw_text('Guard: None', 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 180
          label.draw_text('Guard: None', 25, 210, 0, 3, 1, 1, false)
          last_line = 240
        elsif last_line == 150
          label.draw_text('Guard: None', 25, 180, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 150
          label.draw_text('Guard: None', 25, 180, 0, 3, 1, 1, false)
          last_line = 180
        end
      end

      label.draw_text("TI:    #{transfer_in}",25,last_line+=30,0,3,1,1,false)
      label.draw_text("FUP:   (#{agrees_to_followup})",25,last_line+=30,0,3,1,1,false)

      label2 = ZebraPrinter::StandardLabel.new
      #Vertical lines
      label2.draw_line(25, 170, 795, 3)
      #label data
      label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
      label2.draw_text("(DSA: #{art_start_date&.strftime('%d-%b-%Y') || 'N/A'})", 370, 30, 0, 2, 1, 1, false)
      label2.draw_text(arv_number, 580, 20, 0, 3, 1, 1, false)
      label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}", 25, 300, 0, 1, 1, 1, false)

      label2.draw_text("RFS: #{reason_for_art_eligibility}", 25, 70, 0, 2, 1, 1, false)
      label2.draw_text("#{cd4_count} #{cd4_count_date}", 25, 110, 0, 2, 1, 1, false)
      label2.draw_text("1st + Test: #{hiv_test_date}", 25, 150, 0, 2, 1, 1, false)

      label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}", 380, 70, 0, 2, 1, 1, false)
      label2.draw_text("KS: #{ks}", 380, 110, 0, 2, 1, 1, false)
      label2.draw_text("Preg:#{pregnant}", 380, 150, 0, 2, 1, 1, false)
      label2.draw_text(first_line_drugs.join(',')[0..32], 25, 190, 0, 2, 1, 1, false)
      label2.draw_text(alt_first_line_drugs.join(',')[0..32], 25, 230, 0, 2, 1, 1, false)
      label2.draw_text(second_line_drugs.join(',')[0..32], 25, 270, 0, 2, 1, 1, false)

      label2.draw_text("HEIGHT: #{initial_height}", 570, 70, 0, 2, 1, 1, false)
      label2.draw_text("WEIGHT: #{initial_weight}", 570, 110, 0, 2, 1, 1, false)
      label2.draw_text("Init Age: #{age_at_initiation}", 570, 150, 0, 2, 1, 1, false)

      line = 190
      extra_lines = []
      label2.draw_text('STAGE DEFINING CONDITIONS', 450, 190, 0, 3, 1, 1, false)

      who_clinical_conditions.split(';').each do |condition|
        line += 25
        if line <= 290
          label2.draw_text(condition[0..35], 450, line, 0, 1, 1, 1, false)
        end

        extra_lines << condition[0..79] if line > 290
      end

      if line > 310 && !extra_lines.blank?
        line = 30
        label3 = ZebraPrinter::StandardLabel.new
        label3.draw_text('STAGE DEFINING CONDITIONS', 25, line, 0, 3, 1, 1, false)
        label3.draw_text(identifier('ARV Number'), 370, line, 0, 2, 1, 1, false)
        label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}", 450, 300, 0, 1, 1, 1,false)
        extra_lines.each do |condition|
          label3.draw_text(condition, 25, line += 30, 0, 2, 1, 1, false)
        end
      end

      return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" unless extra_lines.blank?

      "#{label.print(1)} #{label2.print(1)}"
    end

    def age_at_initiation
      date = date_of_first_line_regimen
      return nil unless date

      patient.age(today: date)
    end

    def address
      PersonAddress.where(person_id: patient.id)\
                   .order(:date_created)\
                   .last\
                   &.city_village || ''
    end

    def agrees_to_followup
      recent_observation('Agrees to followup')&.answer_string || 'UNKNOWN'
    end

    def alt_first_line_drugs
      load_regimens unless @alt_first_line_drugs

      @alt_first_line_drugs
    end

    def arv_number
      identifier('ARV Number') || 'N/A'
    end

    def cd4_count
      load_hiv_staging_vars unless @cd4_count

      @cd4_count
    end

    def cd4_count_date
      load_hiv_staging_vars unless @cd4_count_date

      @cd4_count_date
    end

    def date_of_first_line_regimen
      load_regimens unless @date_of_first_line_regimen

      @date_of_first_line_regimen
    end

    def eptb
      return if hiv_staging_observation_present?('Extrapulmonary tuberculosis (EPTB)')

      'eptb'
    end

    def first_line_drugs
      load_regimens unless @first_line_drugs

      @first_line_drugs
    end

    def initial_weight
      obs = initial_observation('Weight')
      return 'Unknown' unless obs

      obs.value_numeric || obs.value_text&.to_f
    end

    def initial_height
      obs = initial_observation('Height (cm)')
      return 'Unknown' unless obs

      obs.value_numeric || obs.value_text&.to_f
    end

    def ks
      return 'Yes' if hiv_staging_observation_present?('Kaposis sarcoma')

      'No'
    end

    def phone_number
      ['Cell phone number', 'Home phone number', 'Office phone number'].each do |name|
        phone_number_value = attribute(name)&.value
        next if phone_number_value.blank? || phone_number_value.match?(/(Not\s*Available|N\/A|Unknown)/i)

        return phone_number_value
      end

      "Unknown"
    end

    def pregnant
      load_hiv_staging_vars unless @pregnant

      @pregnant
    end

    def pulmonary_tb
      if hiv_staging_observation_present?('Pulmonary tuberculosis')\
          || hiv_staging_observation_present?('Pulmonary tuberculosis (current)')
        return
      end

      'Pulmonary tb'
    end

    def reason_for_art_eligibility
      patient_id = ActiveRecord::Base.connection.quote(patient.id)

      reason_for_art = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT patient_reason_for_starting_art_text(#{patient_id}) reason
      SQL

      reason_for_art['reason'] || 'Unknown'
    end

    def second_line_drugs
      load_regimens unless @second_line_drugs

      @second_line_drugs
    end

    def tb_within_last_two_yrs
      return if hiv_staging_observation_present?('Pulmonary tuberculosis within the last 2 years')

      'tb within last 2 yrs'
    end

    def transfer_in
      has_transfer_letter = observation_present?('Has transfer letter')
      return 'Yes' if has_transfer_letter

      date_art_last_taken = recent_observation('Date ART last taken')
      return 'Yes' if date_art_last_taken&.value_datetime

      'No'
    end

    def guardian
      return @guardian if @guardian

      person_id = Relationship.where(person_a: patient.id)\
                              .order(date_created: :desc)\
                              .first\
                              &.person_b

      @guardian = PersonName.where(person_id: person_id).order(:date_created).last&.to_s
    end

    def who_clinical_conditions
      who_clinical_conditions = ""

      (hiv_staging&.observations || []).collect do |obs|
        if GlobalProperty.find_by_property('use.extended.staging.questions')&.property_value == 'true'
          name = obs.to_s.split(':')[0].strip rescue nil
          ans = obs.to_s.split(':')[1].strip rescue nil
          next unless ans.upcase == 'YES'
          visits.who_clinical_conditions = visits.who_clinical_conditions + (name) + "; "
        else
          name = obs.to_s.split(':')[0].strip rescue nil
          next unless name == 'WHO STAGES CRITERIA PRESENT'
          condition = obs.to_s.split(':')[1].strip.humanize rescue nil
          who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
        end
      end

      who_clinical_conditions
    end

    def name
      @name ||= patient.name
    end

    def sex
      @sex ||= patient.person.gender
    end

    def birthdate
      person = patient.person
      return '??/???/????' if person.birthdate.nil?

      return person.birthdate.strftime('%d/%b/%Y') unless person.birthdate_estimated == 1

      # When month of birth is known, birthdate is set to 15
      return person.birthdate.strftime('??/%b/%Y') if person.birthdate.day == 15

      # We probably know the year only then
      person.birthdate.strftime('??/???/%Y')
    end

    def hiv_test_date
      recent_observation('Confirmatory HIV test date')&.value_datetime&.strftime('%d/%b/%Y') || 'N/A'
    end

    def load_hiv_staging_vars
      (hiv_staging&.observations || []).map do |obs|
        case obs.name
        when 'CD4 COUNT DATETIME'
          @cd4_count_date = obs.value_datetime&.to_date
        when 'CD4 COUNT'
          @cd4_count = obs.value_numeric
        when 'IS PATIENT PREGNANT?'
          @pregnant = obs.answer_string
        end
      end
    end

    # Patient's HIV staging encounter
    def hiv_staging
      @hiv_staging ||= Encounter.where(type: EncounterType.find_by_name('HIV Staging'),
                                       patient: patient)\
                                .order(:encounter_datetime)
                                .last
    end

    def hiv_staging_observation_present?(concept_name)
      concept_id = ConceptName.find_by_name(concept_name)&.concept_id
      return false unless hiv_staging

      hiv_staging.observations\
                 .where(concept_id: concept_id)\
                 .order(:obs_datetime)\
                 .first
                 &.value_coded == ConceptName.find_by_name('Yes').concept_id
    end

    # Returns the oldest observation for current patient of the given concept_name
    def initial_observation(concept_name)
      concept_id = ConceptName.select(:concept_id)\
                              .find_by_name(concept_name)\
                              &.concept_id
      return nil unless concept_id

      Observation.where(person_id: patient.id, concept_id: concept_id)\
                 .order(:obs_datetime)\
                 .first
    end

    # Returns most recent observation for the current patient
    def recent_observation(concept_name, extra_filters = {})
      concept_id = ConceptName.find_by_name(concept_name).concept_id
      program_id = Program.find_by_name('HIV Program').id

      Observation.joins(:encounter)
                 .merge(Encounter.where(program_id: program_id))
                 .where(person_id: patient.id, concept_id: concept_id, **extra_filters)
                 .order(:obs_datetime)
                 .last
    end

    # Checks whether the most recent observation of the given concept type
    # has a value of true
    def observation_present?(concept_name, extra_filters = {})
      yes_concept_id = ConceptName.find_by_name('Yes').concept_id
      obs = recent_observation(concept_name, value_coded: yes_concept_id, **extra_filters)
      !obs.nil?
    end

    # Returns current patient's attribute of the given name
    def attribute(attribute_name)
      PersonAttribute.joins(:type)\
                     .where(person_id: patient.id)\
                     .merge(PersonAttributeType.where(name: attribute_name).limit(1))\
                     .first
    end

    def load_regimens
      regimens = {}

      regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
      regimen_types.map do | regimen |
        concept_member_ids = ConceptName.find_by_name(regimen).concept.concept_members.collect{|c|c.concept_id}
        case regimen
        when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        end
      end

      first_treatment_encounters = []

      encounter_type = EncounterType.find_by_name('DISPENSING').id
      amount_dispensed_concept_id = ConceptName.find_by_name('Amount dispensed').concept_id
      regimens.map do | regimen_type , ids |
        encounter = Encounter.joins("INNER JOIN obs ON encounter.encounter_id = obs.encounter_id").where(
          ["encounter_type=? AND encounter.patient_id = ? AND concept_id = ? AND encounter.voided = 0 AND value_drug != ?",
            encounter_type , patient.id , amount_dispensed_concept_id, 297 ]).order("encounter_datetime").first
        first_treatment_encounters << encounter unless encounter.blank?
      end

      @first_line_drugs = []
      @alt_first_line_drugs = []
      @second_line_drugs = []

      first_treatment_encounters.map do |treatment_encounter|
        treatment_encounter.observations.map do |obs|
          next if not obs.concept_id == amount_dispensed_concept_id
          drug = Drug.find(obs.value_drug) if obs.value_numeric > 0
          next if obs.value_numeric <= 0
          drug_concept_id = drug.concept.concept_id
          regimens.map do | regimen_type , concept_ids |
            if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              @date_of_first_line_regimen = art_start_date #treatment_encounter.encounter_datetime.to_date
              @first_line_drugs << drug.concept.shortname
              @first_line_drugs = visits.first_line_drugs.uniq rescue []
            elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              @date_of_first_alt_line_regimen = art_start_date #treatment_encounter.encounter_datetime.to_date
              @alt_first_line_drugs << drug.concept.shortname
              @alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
            elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              @date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
              @second_line_drugs << drug.concept.shortname
              @second_line_drugs = second_line_drugs.uniq rescue []
            end
          end
        end.compact
      end
    end
  end
end
