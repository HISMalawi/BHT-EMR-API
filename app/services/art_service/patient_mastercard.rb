module ARTService
  class PatientMastercard
    def mastercard_demographics(patient_obj, session_date = Date.today)
      patient_bean = PatientService.get_patient(patient_obj.person, session_date)
      visits = Mastercard.new()
      visits.patient_id = patient_obj.id
      visits.arv_number = .arv_number
      visits.address = patient_bean.address
      visits.national_id = patient_bean.national_id
      visits.name = patient_bean.name rescue nil
      visits.sex = patient_bean.sex
      visits.age = patient_bean.age
      visits.occupation = PatientService.get_attribute(patient_obj.person, 'Occupation')
      visits.landmark = patient_obj.person.addresses.first.address1 rescue nil
      visits.init_wt = PatientService.get_patient_attribute_value(patient_obj, "initial_weight")
      visits.init_ht = PatientService.get_patient_attribute_value(patient_obj, "initial_height")
      visits.bmi = PatientService.get_patient_attribute_value(patient_obj, "initial_bmi")
      visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
      visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
      visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
      visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
      visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
      location_name = Location.find_by_location_id(visits.hiv_test_location.to_s.split(':')[1].strip).name rescue nil
      visits.hiv_test_location = location_name rescue nil
      visits.guardian = art_guardian(patient_obj) #rescue nil
      visits.reason_for_art_eligibility = PatientService.reason_for_art_eligibility(patient_obj)
      visits.transfer_in = PatientService.is_transfer_in(patient_obj) rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
      visits.transfer_in == false ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

      transferred_out_details = Observation.where(["concept_id = ? and person_id = ?",
          ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_bean.patient_id]).last rescue ""

      visits.transferred_out_to = transferred_out_details.value_text if transferred_out_details
      visits.transferred_out_date = transferred_out_details.obs_datetime if transferred_out_details

      visits.art_start_date = PatientService.patient_art_start_date(patient_bean.patient_id).strftime("%d-%B-%Y") rescue nil

      visits.transfer_in_date = patient_obj.person.observations.recent(1).question("HAS TRANSFER LETTER").all.collect{|o|
        o.obs_datetime if o.answer_string.strip == "YES"}.last rescue nil

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
            encounter_type , patient_obj.id , amount_dispensed_concept_id, 297 ]).order("encounter_datetime").first
        first_treatment_encounters << encounter unless encounter.blank?
      end

      visits.first_line_drugs = []
      visits.alt_first_line_drugs = []
      visits.second_line_drugs = []

      first_treatment_encounters.map do | treatment_encounter |
        treatment_encounter.observations.map{|obs|
          next if not obs.concept_id == amount_dispensed_concept_id
          drug = Drug.find(obs.value_drug) if obs.value_numeric > 0
          next if obs.value_numeric <= 0
          drug_concept_id = drug.concept.concept_id
          regimens.map do | regimen_type , concept_ids |
            if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              visits.date_of_first_line_regimen =  PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
              visits.first_line_drugs << drug.concept.shortname
              visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
            elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              visits.date_of_first_alt_line_regimen = PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
              visits.alt_first_line_drugs << drug.concept.shortname
              visits.alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
            elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' #and concept_ids.include?(drug_concept_id)
              visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
              visits.second_line_drugs << drug.concept.shortname
              visits.second_line_drugs = visits.second_line_drugs.uniq rescue []
            end
          end
        }.compact
      end

      ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis (current)","Kaposis sarcoma","Pulmonary tuberculosis"]

      staging_ans = patient_obj.person.observations.recent(1).question("WHO STAGES CRITERIA PRESENT").all

      if !staging_ans.blank?
        staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all
      end

      hiv_staging_obs = Encounter.where(["encounter_type = ? and patient_id = ?",
          EncounterType.find_by_name("HIV Staging").id,patient_obj.id]).last.observations rescue []


      if !staging_ans.blank?
        #ks
        if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
          visits.ks = 'Yes'
        end rescue nil

        #tb_within_last_two_yrs
        if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
          visits.tb_within_last_two_yrs = 'Yes'
        end rescue nil

        #eptb
        if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
          visits.eptb = 'Yes'
        end rescue nil

        #pulmonary_tb
        if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])
          visits.pulmonary_tb = 'Yes'
        end rescue nil

        #pulmonary_tb
        if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[4])
          visits.pulmonary_tb = 'Yes'
        end rescue nil
      else
        if !hiv_staging_obs.blank?
          tb_within_2yrs_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis within the last 2 years').concept_id
          ks_concept_id = ConceptName.find_by_name('Kaposis sarcoma').concept_id
          pulm_tuber_cur_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis (current)').concept_id
          pulm_tuber_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis').concept_id
          eptb_concept_id = ConceptName.find_by_name('Extrapulmonary tuberculosis (EPTB)').concept_id

          (hiv_staging_obs || []).each do |obs|
            #checking if answer is 'Yes'
            if obs.value_coded == 1065
              if obs.concept_id == tb_within_2yrs_concept_id
                visits.tb_within_last_two_yrs = 'Yes'
              end

              if obs.concept_id == eptb_concept_id
                visits.eptb = 'Yes'
              end

              if obs.concept_id == ks_concept_id
                visits.ks = 'Yes'
              end

              if obs.concept_id == pulm_tuber_cur_concept_id
                visits.pulmonary_tb = 'Yes'
              end

              if obs.concept_id == pulm_tuber_concept_id
                visits.pulmonary_tb = 'Yes'
              end
            elsif obs.value_coded == 1066
              if obs.concept_id == tb_within_2yrs_concept_id
                visits.tb_within_last_two_yrs = 'No'
              end

              if obs.concept_id == eptb_concept_id
                visits.eptb = 'No'
              end

              if obs.concept_id == ks_concept_id
                visits.ks = 'No'
              end

              if obs.concept_id == pulm_tuber_cur_concept_id
                visits.pulmonary_tb = 'No'
              end

              if obs.concept_id == pulm_tuber_concept_id
                visits.pulmonary_tb = 'No'
              end
            end
          end
        end
      end

  =begin
      staging_ans = patient_obj.person.observations.recent(1).question("WHO STAGES CRITERIA PRESENT").all

      hiv_staging_obs = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
                                                            EncounterType.find_by_name("HIV Staging").id,patient_obj.id]).observations.map(&:concept_id) rescue []

      if staging_ans.blank?
        staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all
      end

      if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
        visits.ks = 'Yes'
      else
        ks_concept_id = ConceptName.find_by_name('Kaposis sarcoma').concept_id
        visits.ks = 'Yes' if hiv_staging_obs.include?(ks_concept_id)
      end

      if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
        visits.tb_within_last_two_yrs = 'Yes'
      else
        tb_within_2yrs_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis within the last 2 years').concept_id
        visits.tb_within_last_two_yrs = 'Yes' if hiv_staging_obs.include?(tb_within_2yrs_concept_id)
      end

      if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
        visits.eptb = 'Yes'
      else
        eptb_concept_id = ConceptName.find_by_name('Extrapulmonary tuberculosis (EPTB)').concept_id
        visits.eptb = 'Yes' if hiv_staging_obs.include?(eptb_concept_id)
      end

      if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])
        visits.pulmonary_tb = 'Yes'
      else
        pulm_tuber_cur_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis (current)').concept_id
        visits.pulmonary_tb = 'Yes' if hiv_staging_obs.include?(pulm_tuber_cur_concept_id)
      end

      if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[4])
        visits.pulmonary_tb = 'Yes'
      else
        pulm_tuber_concept_id = ConceptName.find_by_name('Pulmonary tuberculosis').concept_id
        visits.pulmonary_tb = 'Yes' if hiv_staging_obs.include?(pulm_tuber_concept_id)
      end
  =end
      hiv_staging = Encounter.where(["encounter_type = ? and patient_id = ?",
          EncounterType.find_by_name("HIV Staging").id,patient_obj.id]).last

      visits.who_clinical_conditions = ""
      (hiv_staging.observations).collect do |obs|
        if CoreService.get_global_property_value('use.extended.staging.questions').to_s == 'true'
          name = obs.to_s.split(':')[0].strip rescue nil
          ans = obs.to_s.split(':')[1].strip rescue nil
          next unless ans.upcase == 'YES'
          visits.who_clinical_conditions = visits.who_clinical_conditions + (name) + "; "
        else
          name = obs.to_s.split(':')[0].strip rescue nil
          next unless name == 'WHO STAGES CRITERIA PRESENT'
          condition = obs.to_s.split(':')[1].strip.humanize rescue nil
          visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
        end
      end rescue []

      visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

      (hiv_staging.observations).map do | obs |
        concept_name = obs.to_s.split(':')[0].strip rescue nil
        next if concept_name.blank?
        case concept_name.downcase
        when 'cd4 count datetime'
          visits.cd4_count_date = obs.value_datetime.to_date
        when 'cd4 count'
          visits.cd4_count = "#{obs.value_modifier}#{obs.value_numeric.to_i}"
        when 'is patient pregnant?'
          visits.pregnant = obs.to_s.split(':')[1] rescue nil
        when 'lymphocyte count'
          visits.tlc = obs.answer_string
        when 'lymphocyte count date'
          visits.tlc_date = obs.value_datetime.to_date
        end
      end rescue []

      visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
          (!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ?
              "Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

      hiv_clinic_registration = Encounter.where(["encounter_type = ? and patient_id = ?",
          EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,patient_obj.id]).last

      (hiv_clinic_registration.observations).map do | obs |
        concept_name = obs.to_s.split(':')[0].strip rescue nil
        next if concept_name.blank?
        case concept_name
        when 'Ever received ART?'
          visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
        when 'Last ART drugs taken'
          visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
        when 'Date ART last taken'
          visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
        when 'Confirmatory HIV test location'
          visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
        when 'ART number at previous location'
          visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
        when 'Confirmatory HIV test type'
          visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
        when 'Confirmatory HIV test date'
          visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
        end
      end rescue []

      visits
    end
  end
end