# frozen_string_literal: true
require "json"

class OpdService::VisitLabel
  attr_reader :date, :patient

  include ModelUtils

  def initialize(patient, date)
    @patient = patient
    @date = date
  end

  def filter_drug_instraction(o)
    instruction_list = ""
    o = o.split("\n")
    o.each { |x|
      drug_name = x.split(":")[0]
      units = Drug.find_by_name(drug_name).units
      if (drug_name.length() > 30)
        drug_name = drug_name.truncate(27)
      end
      drug_instructions = x.split(":")[1].split("for")
      drug_dos_fre = drug_instructions[0].split(" ")
      drug_fre = covert_freq(x.split(":")[1])
      drug_duration = drug_instructions[1].delete(" ")
      if (drug_duration == "1days")
        drug_duration = "1day"
      end
      instruction_list = instruction_list + drug_name + ":" + drug_dos_fre[0] + units + drug_fre + " - " + drug_duration + "\n"
    }
    return instruction_list
  end

  def covert_freq(freq)
    if (freq.include? "(OD)")
      return "(1X/D)"
    elsif (freq.include? "(BD)")
      return "(2X/D)"
    elsif (freq.include? "(TDS)")
      return "(3X/D)"
    elsif (freq.include? "(QID)")
      return "(4X/D)"
    elsif (freq.include? "(5X/D)")
      return "(5X/D)"
    elsif (freq.include? "(Q4HRS)")
      return "(6X/D)"
    elsif (freq.include? "(QAM)")
      return "(Morning)"
    elsif (freq.include? "(QWK)")
      return "(1X/WK)"
    elsif (freq.include? "Once a month")
      return "(1X/MTH)"
    elsif (freq.include? "Twice a month")
      return "(2X/MTH)"
    end
    return ""
  end

  def print
    label = ZebraPrinter::Lib::StandardLabel.new
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 50
    title_header_font = { :font_reverse => false, :font_size => 4, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1 }
    concepts_font = { :font_reverse => false, :font_size => 3, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1 }
    title_font_top_bottom = { :font_reverse => false, :font_size => 4, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1 }
    title_font_bottom = { :font_reverse => false, :font_size => 2, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1 }
    units = { "WEIGHT" => "kg", "HT" => "cm" }
    encs = patient.encounters.where("DATE(encounter_datetime) = ?", date).order(Arel.sql("encounter_datetime ASC"))
    return nil if encs.blank?

    # Initialize the JSON object as a hash
    json_data = {
      visit: {
        start_time: encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M"),
        end_time: encs.last.encounter_datetime.strftime("%d/%b/%Y %H:%M"),
      },
      treatments: [],
      procedures: [],
      hiv_status: [],
      lab_orders: [],
      diagnoses: [],
      transfer_out: nil,
      notes: [],
      admissions: [],
      outcomes: [],
      vitals: [],
      referral: nil,
      seen_by: {},
    }

    label.draw_multi_text("Visit: #{json_data[:visit][:start_time]} - #{json_data[:visit][:end_time]}", title_font_top_bottom)
    label.draw_line(20, 60, 800, 2, 0)

    outcomes = []
    vitals = []
    notes = []
    check_vitals = encs.map(&:name).include?("VITALS")
    check_notes = encs.map(&:name).include?("NOTES")

    encs.each do |encounter|
      if encounter.name.upcase.include?("TREATMENT")
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        o = encounter.orders.collect { |order| order.drug_order.to_s if order.order_type_id == OrderType.find_by_name("Drug Order").order_type_id }.join("\n")
        o = "No prescriptions have been made" if o.blank?
        o = "TREATMENT NOT DONE" if treatment_not_done(encounter.patient, date)

        # Push data to the label
        label.draw_multi_text("Prescriptions at #{encounter_datetime}", title_header_font)
        label.draw_multi_text("#{o}", concepts_font)

        # Push data to JSON object
        json_data[:treatments] << { time: encounter_datetime, prescriptions: o }
      elsif encounter.name.upcase.include?("PROCEDURES DONE")
        procs = ["Procedures - "]
        procs << encounter.observations.collect { |observation|
          observation.answer_string.squish if !observation.concept.fullname.match(/Workstation location/i)
        }.compact.join("; ")

        label.draw_multi_text("#{procs}", concepts_font)
        json_data[:procedures] << procs.join(", ")
      elsif encounter.name.upcase.include?("UPDATE HIV STATUS")
        hiv_status = []
        encounter.observations.each do |observation|
          next if !observation.concept.fullname.match(/HIV STATUS/i)
          hiv_status << "HIV Status - " + observation.answer_string.to_s rescue ""
        end
        label.draw_multi_text("#{hiv_status}", :font_reverse => false)
        json_data[:hiv_status] << hiv_status
      elsif encounter.name.upcase.include?("LAB ORDERS")
        lab_orders = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.fullname
          next if concept_name.match(/Workstation location/i)
          lab_orders << observation.answer_string.to_s
        end
        label.draw_multi_text("Lab orders: #{lab_orders.join(",")}", concepts_font)
        json_data[:lab_orders] << lab_orders.join(", ")
      elsif encounter.name.upcase.include?("DIAGNOSIS")
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        obs = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.fullname
          next if concept_name.match(/Workstation location/i)
          next if !observation.obs_group_id.blank?

          child_obs = Observation.where("obs_group_id = ?", observation.obs_id)
          if !child_obs.empty?
            text = observation.answer_string.to_s + " - "
            count = 0
            child_obs.each do |child_observation|
              text += ", " if count > 0
              text += child_observation.answer_string.to_s
              count += 1
            end
            obs << text
          else
            obs << observation.answer_string.to_s
          end
        end
        label.draw_multi_text("Diagnoses at #{encounter_datetime}", title_header_font)
        obs.each { |observation| label.draw_multi_text("#{observation}", concepts_font) }
        json_data[:diagnoses] << { time: encounter_datetime, observations: obs }
      elsif encounter.name.upcase.include?("TRANSFER OUT")
        obs = ["Referred to facility - "]
        obs << encounter.observations.collect { |observe|
          Location.find("#{observe.answer_string}".squish).name if observe.concept.fullname.upcase.include?("TRANSFER")
        }.compact.join("; ")

        label.draw_multi_text("Transfer Out", :font_reverse => true)
        label.draw_multi_text("#{obs}", concepts_font)
        json_data[:transfer_out] = obs.join(", ")
      elsif encounter.name.upcase.include?("NOTES")
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        obs = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.concept_names.last.name
          next if concept_name.match(/Workstation location/i)
          next if concept_name.match(/Life threatening condition/i)
          next if concept_name.match(/Triage category/i)
          next if !observation.obs_group_id.blank?

          child_obs = Observation.where("obs_group_id = ?", observation.obs_id)
          if !child_obs.empty?
            text = observation.answer_string.to_s + " - "
            count = 0
            child_obs.each do |child_observation|
              text += ", " if count > 0
              text += child_observation.answer_string.to_s
              count += 1
            end
            obs << text
          else
            obs << observation.answer_string.to_s
          end
          notes << obs
        end
        if (check_vitals == false)
          label.draw_multi_text("Notes at #{encounter_datetime}", title_header_font)
          label.draw_multi_text("#{obs.join(",")}", concepts_font)
        end
        json_data[:notes] << { time: encounter_datetime, observations: obs.join(", ") }
      elsif encounter.name.upcase.include?("ADMIT PATIENT")
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        obs = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.concept_names.last.name
          next if concept_name.match(/Workstation location/i)
          obs << observation.answer_string
        end
        label.draw_multi_text("Patient admission at #{encounter_datetime}", title_header_font)
        label.draw_multi_text("#{obs}", concepts_font)
        json_data[:admissions] << { time: encounter_datetime, observations: obs.join(", ") }
      elsif encounter.name.upcase.include?("PATIENT SENT HOME")
        outcomes << "Sent home"
      elsif encounter.name.upcase.include?("REFERRAL")
        outcomes << "Referred"
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        obs = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.fullname
          next if concept_name.match(/Workstation location/i)
          obs << observation.answer_string
        end
        string = []
        string << "Referred to : " + obs.first
        string << "Specialist clinic : " + obs.last
        label.draw_multi_text("Referral at #{encounter_datetime}", title_header_font)
        string.each { |observation| label.draw_multi_text("#{observation}", concepts_font) }
        json_data[:referral] = { time: encounter_datetime, details: string }
      elsif encounter.name.upcase.include?("VITALS")
        vital_signs = ["HT", "Weight", "Heart rate", "Temperature", "RR", "SAO2", "MUAC"]
        encounter_datetime = encounter.encounter_datetime.strftime("%H:%M")
        string = []
        obs = []
        complaints = []
        bp = []
        encounter.observations.each do |observation|
          concept_name = observation.concept.concept_names.last.name
          next if concept_name.match(/Workstation location/i)
          next if !observation.obs_group_id.blank?

          child_obs = Observation.where("obs_group_id = ?", observation.obs_id)
          if !child_obs.empty?
            text = observation.answer_string.to_s + " : "
            count = 0
            child_obs.each do |child_observation|
              text += ", " if count > 0
              text += child_observation.answer_string.to_s
              count += 1
            end
            obs << text
          else
            string << observation.concept.fullname + ":" + observation.answer_string if vital_signs.include?(concept_name)
            bp << observation.answer_string if concept_name.match(/TA/i)
            bp << observation.answer_string if concept_name.match(/DIASTOLIC/i)
            if !vital_signs.include?(concept_name)
              if !concept_name.match(/TA/i)
                if !concept_name.match(/DIASTOLIC/i)
                  if !concept_name.match(/LIFE THREATENING CONDITION/i)
                    if !concept_name.match(/TRIAGE CATEGORY/i)
                      obs << observation.answer_string.to_s
                    end
                  end
                  complaints << concept_name + ":" + observation.answer_string if concept_name.match(/LIFE THREATENING CONDITION/i)
                  complaints << concept_name + ":" + observation.answer_string if concept_name.match(/TRIAGE CATEGORY/i)
                end
              end
            end
          end
          vitals << obs << string
        end

        unless bp.blank?
          sbp = bp[0]
          dbp = bp[1]
          string << ("BP: " + sbp.to_s.squish + "/" + dbp.to_s.squish)
        end

        if (check_notes == false)
          label.draw_multi_text("Vitals at #{encounter_datetime}", title_header_font)
          label.draw_multi_text("#{string.join(",")}", concepts_font)
          label.draw_multi_text("Presenting complaints\n #{obs.join(",")}", concepts_font) if !obs.blank?

          unless complaints.blank?
            complaints.each { |complaint| label.draw_multi_text("#{complaint}", concepts_font) }
          end
        end

        json_data[:vitals] << { time: encounter_datetime, vitals: string.join(", "), complaints: complaints.join(", ") }
      end
    end

    if (check_notes && check_vitals)
      combined = (vitals + notes).flatten.sort.uniq
      label.draw_multi_text("NOTES AND VITALS", title_header_font)
      label.draw_multi_text("#{combined.join(",")}", concepts_font)
      json_data[:notes_and_vitals] = combined.join(", ")
    end

    ["OPD PROGRAM", "IPD PROGRAM"].each do |program_name|
      program_id = Program.find_by_name(program_name).id
      state = patient.patient_programs.local.select { |p| p.program_id == program_id }.last.patient_states.last rescue nil

      next if state.nil?

      state_start_date = state.start_date.to_date
      state_name = state.program_workflow_state.concept.fullname

      if ((state_start_date == session[:datetime]) || (state_start_date.to_date == Date.today)) && (state_name.upcase != "FOLLOWING")
        outcomes << state_name
      end
    end

    unless outcomes.blank?
      label.draw_multi_text("Outcomes : #{outcomes.uniq.join(",")}", concepts_font)
      json_data[:outcomes] = outcomes.uniq
    end

    program_id = Program.find_by_name("OPD Program").program_id
    user_id = Encounter.where(patient_id: patient["patient_id"], program_id: program_id).order(encounter_datetime: :desc).first.creator
    initial = User.find(user_id).person.names.last.given_name.first + "."
    last_name = User.find(user_id).person.names.last.family_name
    label.draw_multi_text("___________________________________________________", concepts_font)
    label.draw_multi_text("Seen by: #{initial + last_name} at #{Location.current.name}", title_font_bottom)

    # Add seen_by information to JSON object
    json_data[:seen_by] = { initial: initial, last_name: last_name, location: Location.current.name }

    json_data[:zpl] = label.print(1)

    json_data
  end

  def treatment_not_done(patient, date)
    current_treatment_encounter(patient, date).first.observations.where(
      "obs.concept_id = ?", ConceptName.find_by_name("TREATMENT").concept_id
    ).last rescue false
  end

  def current_treatment_encounter(patient, date, force = false)
    type = EncounterType.find_by_name("TREATMENT")
    program_id = Program.find_by_name("OPD Program").program_id

    encounter = patient.encounters.find_by(
      "program_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?", program_id, type, date
    )

    return encounter
  end
end
