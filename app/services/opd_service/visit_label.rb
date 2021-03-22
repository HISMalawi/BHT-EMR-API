# frozen_string_literal: true

class OPDService::VisitLabel
  attr_reader :date, :patient

  include ModelUtils

  def initialize(patient, date)
    @patient = patient
    @date = date
  end

  def print
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 50
    title_header_font = {:font_reverse => false,:font_size => 4, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1}
    concepts_font = {:font_reverse => false, :font_size => 3, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1 }
    title_font_top_bottom = {:font_reverse => false, :font_size => 4, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1}
    title_font_bottom = {:font_reverse => false, :font_size => 2, :font_horizontal_multiplier => 1, :font_vertical_multiplier => 1}
    units = {"WEIGHT"=>"kg", "HT"=>"cm"}
    encs = patient.encounters.where('DATE(encounter_datetime) = ?', date).order(Arel.sql('encounter_datetime ASC'))
    return nil if encs.blank?
    label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}" +
      " - #{encs.last.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", title_font_top_bottom)
    label.draw_line(20, 60, 800, 2, 0)
    outcomes = []
    vitals = []
    notes = []
    check_vitals = encs.map(&:name).include?('VITALS')
    check_notes = encs.map(&:name).include?('NOTES')
    encs.each {|encounter|
        if encounter.name.upcase.include?('TREATMENT')
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          o = encounter.orders.collect{ |order| order.drug_order.to_s if order.order_type_id == OrderType.find_by_name('Drug Order').order_type_id }.join("\n")
          o = "No prescriptions have been made" if o.blank?
          o = "TREATMENT NOT DONE" if treatment_not_done(encounter.patient, date)
          label.draw_multi_text("Prescriptions at #{encounter_datetime}", title_header_font)
          label.draw_multi_text("#{o}", concepts_font)

        elsif encounter.name.upcase.include?("PROCEDURES DONE")
          procs = ["Procedures - "]
          procs << encounter.observations.collect{|observation|
            observation.answer_string.squish if !observation.concept.fullname.match(/Workstation location/i)
          }.compact.join("; ")
          label.draw_multi_text("#{procs}", concepts_font)

        elsif encounter.name.upcase.include?('UPDATE HIV STATUS')
          hiv_status = []
          encounter.observations.each do |observation|
          next if !observation.concept.fullname.match(/HIV STATUS/i)
          hiv_status << 'HIV Status - ' + observation.answer_string.to_s rescue ''
          end
          label.draw_multi_text("#{hiv_status}", :font_reverse => false)

        elsif encounter.name.upcase.include?('LAB ORDERS')
          lab_orders = []
          encounter.observations.each do |observation|
          concept_name = observation.concept.fullname
          next if concept_name.match(/Workstation location/i)
            lab_orders << observation.answer_string.to_s
          end
          label.draw_multi_text("Lab orders: #{lab_orders.join(',')}", concepts_font)

        elsif encounter.name.upcase.include?('DIAGNOSIS')
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          obs = []
          encounter.observations.each{|observation|
          concept_name = observation.concept.fullname
          next if concept_name.match(/Workstation location/i)
          next if !observation.obs_group_id.blank?

            child_obs = Observation.where('obs_group_id = ?', observation.obs_id)

            if !child_obs.empty?
              text = observation.answer_string.to_s + " - "
              count = 0
              child_obs.each { | child_observation |
                text = text + ", " if count > 0
                text = text + child_observation.answer_string.to_s
                count = count + 1
              }
              obs << text
            else
              obs << observation.answer_string.to_s
            end
          }
            #"#{observe.answer_string}".squish rescue nil if observe.concept.fullname.upcase.include?('DIAGNOSIS')
          #.compact.join("; ")
          label.draw_multi_text("Diagnoses at #{encounter_datetime}",title_header_font )
          obs.each { | observation |
              label.draw_multi_text("#{observation}", concepts_font)
          }
        elsif encounter.name.upcase.include?('TRANSFER OUT')
          obs = ["Referred to facility - "]
          obs << encounter.observations.collect{|observe|
            Location.find("#{observe.answer_string}".squish).name if observe.concept.fullname.upcase.include?('TRANSFER')}.compact.join("; ")
          obs
          label.draw_multi_text("Transfer Out", :font_reverse => true)
          label.draw_multi_text("#{obs}", concepts_font)

        elsif encounter.name.upcase.include?("NOTES")
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          obs = []
          encounter.observations.each { | observation |

            concept_name = observation.concept.concept_names.last.name
            next if concept_name.match(/Workstation location/i)
            next if concept_name.match(/Life threatening condition/i)
            next if concept_name.match(/Triage category/i)
            next if concept_name.match(/specific presenting complaint/i)
            next if !observation.obs_group_id.blank?

            child_obs = Observation.where('obs_group_id = ?', observation.obs_id)

            if !child_obs.empty?
              text = observation.answer_string.to_s + " - "
              count = 0
              child_obs.each { | child_observation |
                text = text + ", " if count > 0
                text = text + child_observation.answer_string.to_s
                count = count + 1
              }
              obs << text
            else
              obs << observation.answer_string.to_s
            end
            notes << obs
          }
          notes
          if (check_vitals == false)
            label.draw_multi_text("Notes at #{encounter_datetime}",title_header_font)
            label.draw_multi_text("#{obs.join(',')}",concepts_font)
          end

        elsif encounter.name.upcase.include?("ADMIT PATIENT")
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          obs = []
          encounter.observations.each do |observation|
            concept_name = observation.concept.concept_names.last.name
            next if concept_name.match(/Workstation location/i)
              obs << observation.answer_string
          end
          label.draw_multi_text("Patient admission at #{encounter_datetime}", title_header_font)
          label.draw_multi_text("#{obs}", concepts_font)
        elsif encounter.name.upcase.include?("PATIENT SENT HOME")
            outcomes << "Sent home"
        elsif encounter.name.upcase.include?("REFERRAL")
          outcomes << "Referred"
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          obs = []
          encounter.observations.each do |observation|
            concept_name = observation.concept.fullname
            next if concept_name.match(/Workstation location/i)
            obs << observation.answer_string
          end
          string = []
          string << 'Referred to : ' + obs.first
          string << 'Specialist clinic : ' + obs.last
          label.draw_multi_text("Referral at #{encounter_datetime}", title_header_font)
          string.each { | observation |
            label.draw_multi_text("#{observation}", concepts_font)
          }

        elsif encounter.name.upcase.include?("VITALS")
          vital_signs = ["HT","Weight","Heart rate","Temperature","RR","SAO2", "MUAC"]
            #blood_pressure = ["TA", "Diastolic"]
            #SAO2 for oxygen saturation;
            #TA for Systolic blood pressure
            #MUAC for middle upper arm circumference
          encounter_datetime = encounter.encounter_datetime.strftime('%H:%M')
          string = []
          obs = []
          complaints = [] #to hold life threatening condition and triage category
                          #so that they should be printed in different lines
          bp = []
          encounter.observations.each { | observation |

          # if (observation.concept_id == 8578)
            concept_name = observation.concept.concept_names.last.name
            #next if concept_name.match(/Detailed presenting complaint/i)
            next if concept_name.match(/Workstation location/i)
            next if !observation.obs_group_id.blank?

            child_obs = Observation.where('obs_group_id = ?', observation.obs_id)

            if !child_obs.empty?
              text = observation.answer_string.to_s + " : "
              count = 0
              child_obs.each { | child_observation |
                text = text + ", " if count > 0
                text = text + child_observation.answer_string.to_s
                count = count + 1
              }
              obs << text
            else
              string << observation.concept.fullname + ':' + observation.answer_string if vital_signs.include?(concept_name)
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
                    complaints << concept_name + ':' + observation.answer_string if concept_name.match(/LIFE THREATENING CONDITION/i)
                    complaints << concept_name + ':' + observation.answer_string if concept_name.match(/TRIAGE CATEGORY/i)
                  end
                end
              end
            end
            vitals << obs << string
          }

          unless bp.blank?
            sbp = bp[0]
            dbp = bp[1]
            string << ('BP: ' + sbp.to_s.squish + '/' + dbp.to_s.squish )
          end

          vitals
          if (check_notes == false)
            label.draw_multi_text("Vitals at #{encounter_datetime}", title_header_font)
            label.draw_multi_text("#{string.join(',')}", concepts_font)
            #label.draw_multi_text("Presenting complaints", title_header_font)
            label.draw_multi_text("Presenting complaints\n #{obs.join(',')}", concepts_font) if !obs.blank?

            unless complaints.blank?
              complaints.each { | complaint |
                label.draw_multi_text("#{complaint}", concepts_font)
              }
            end

          end
      end

    }
    if ((check_notes == true) && (check_vitals == true))
        combined = (vitals + notes).flatten.sort.uniq #Trying to remove the duplicate entries
        label.draw_multi_text("NOTES AND VITALS", title_header_font)
        label.draw_multi_text("#{combined.join(',')}", concepts_font)
        #combined.each { | value |
          #label.draw_multi_text("#{value}", concepts_font)
        #}
    end
    ['OPD PROGRAM','IPD PROGRAM'].each do |program_name|
        program_id = Program.find_by_name(program_name).id
        state = patient.patient_programs.local.select{|p|
          p.program_id == program_id
        }.last.patient_states.last rescue nil

        next if state.nil?

        state_start_date = state.start_date.to_date
        state_name = state.program_workflow_state.concept.fullname

        if ((state_start_date == session[:datetime]) || (state_start_date.to_date == Date.today)) && (state_name.upcase != 'FOLLOWING')
          outcomes << state_name
          #label.draw_multi_text("Outcome : #{state_name}", concepts_font)
        end
        unless outcomes.blank?
          label.draw_multi_text("Outcomes : #{outcomes.uniq.join(',')}", concepts_font)
        end
    end
    initial = User.current.person.names.last.given_name.first + "."
    last_name = User.current.person.names.last.family_name
    label.draw_multi_text("___________________________________________________", concepts_font)
    label.draw_multi_text("Seen by: #{initial + last_name} at " +
      " #{Location.current.name}", title_font_bottom)

    label.print(1)
  end

  def treatment_not_done(patient, date)
    current_treatment_encounter(patient, date).first.observations.where(
      'obs.concept_id = ?', ConceptName.find_by_name('TREATMENT').concept_id
    ).last rescue false
  end

  def current_treatment_encounter(patient, date, force = false)
    type = EncounterType.find_by_name('TREATMENT')
    program_id = Program.find_by_name('OPD Program').program_id

    encounter = patient.encounters.find_by(
      'program_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?', program_id, type, date
    )

    return encounter
  end
end
