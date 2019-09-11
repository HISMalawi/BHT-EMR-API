# frozen_string_literal: true

module ANCService
    class PatientLabLabel
      attr_accessor :patient, :date

      LAB_RESULTS = EncounterType.find_by name: "LAB RESULTS"
      ANC_PROGRAM = Program.find_by name: "ANC PROGRAM"

      def initialize(patient, date)
        @patient = patient
        @date = date
      end

      def print
        syphil = {}
        @patient.encounters.where(["encounter_type IN (?) AND program_id = ?",
          LAB_RESULTS.id, ANC_PROGRAM.id]).each{|e|
            e.observations.each{|o|
              concept_name = o.concept.concept_names.map(& :name).last.upcase;
              syphil[concept_name] = o.answer_string.squish.upcase
              syphil["encounter_date"] = e.encounter_datetime.to_date.strftime("%Y-%m-%d")

              syphil["HIV TEST DATE"] = e.encounter_datetime.to_date.strftime("%Y-%m-%d") if (concept_name == "PREVIOUS HIV TEST RESULTS" || concept_name == "HIV STATUS")
            }
      }

      @encounter_datetime = syphil["encounter_date"]

      @syphilis = syphil["SYPHILIS TEST RESULT"].titleize rescue ""

      @syphilis_date = syphil["SYPHILIS TEST RESULT"].match(/not done/i) ? "" : syphil["SYPHILIS TEST RESULT DATE"] rescue nil

      @malaria = syphil["MALARIA TEST RESULT"].titleize rescue ""

      @blood_group = syphil["BLOOD GROUP"] rescue ""

      @malaria_date = syphil["MALARIA TEST RESULT"].match(/not done/i)? "" : syphil["DATE OF LABORATORY TEST"] rescue nil

      hiv_test = syphil["HIV STATUS"].blank? ? syphil["PREVIOUS HIV TEST RESULTS"] : syphil["HIV STATUS"]

      @hiv_test = (hiv_test.downcase == "positive" ? "=" :
          (hiv_test.downcase == "negative" ? "-" : "")) rescue ""

      #@hiv_test_date = syphil["HIV STATUS"].match(/not done/i) ? "" : syphil["HIV TEST DATE"] rescue nil

      hiv_test_date = syphil["HIV TEST DATE"].blank? ? syphil["PREVIOUS HIV TEST DATE"] :  syphil["HIV TEST DATE"] rescue nil

      @hiv_test_date = hiv_test_date.to_date.strftime("%Y-%m-%d") rescue ""

      hb = {}; pos = 1;

      @patient.encounters.where(["encounter_type = ?",
          EncounterType.find_by_name("LAB RESULTS").id]).order("encounter_datetime DESC").each{|e|
        e.observations.each{|o| hb[o.concept.concept_names.map(& :name).last.upcase + " " +
              pos.to_s] = o.answer_string.squish.upcase; pos += 1 if o.concept.concept_names.map(& :name).last.upcase == "HB TEST RESULT DATE";
        }
      }

      @hb = syphil['HB TEST RESULT'] + " g/dl" rescue nil

      #@hb1_date = hb["HB TEST RESULT DATE 1"] rescue nil

      @hb2 = hb["HB TEST RESULT 2"] rescue nil

      @hb2_date = hb["HB TEST RESULT DATE 2"] rescue nil

      @cd4 = syphil['CD4 COUNT'] rescue nil

      @cd4_date = syphil['CD4 COUNT DATETIME'] rescue nil

      @height = current_height.to_f # rescue nil

      @weight = current_weight.to_f

      @multiple = Observation.where(["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.where(["encounter_type = ?",
              EncounterType.find_by_name("CURRENT PREGNANCY").id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('Multiple Gestation').concept_id]).last.answer_string.squish rescue nil

      @who = Encounter.find_by_sql("SELECT who_stage(#{@patient.id}, #{(session[:datetime] ?
        session[:datetime].to_date : Date.today)})") rescue nil

      label = ZebraPrinter::StandardLabel.new

      label.draw_text("Examination",28,9,0,1,1,2,false)
      label.draw_line(25,35,115,1,0)
      label.draw_line(180,140,250,1,0)

      label.draw_text("Height",28,56,0,2,1,1,false)
      label.draw_text("Weight",28,86,0,2,1,1,false)

      label.draw_text("Lab Tests",28,111,0,1,1,2,false)
      label.draw_text("Date",190,120,0,2,1,1,false)
      label.draw_text("Result",325,120,0,2,1,1,false)
      label.draw_text("HIV",28,146,0,2,1,1,false)
      label.draw_text("Syphilis",28,176,0,2,1,1,false)
      label.draw_text("Hb",28,206,0,2,1,1,false)
      #label.draw_text("Hb2",28,256,0,2,1,1,false)
      label.draw_text("Malaria",28,236,0,2,1,1,false)
      label.draw_text("Blood Group",28,266,0,2,1,1,false)
      label.draw_line(260,50,170,1,0)
      label.draw_line(260,50,1,60,0)
      label.draw_line(180,286,250,1,0)
      label.draw_line(430,50,1,60,0)

      label.draw_line(180,140,1,145,0)
      label.draw_line(320,140,1,145,0)
      label.draw_line(430,140,1,145,0)

      label.draw_line(260,80,170,1,0)
      label.draw_line(260,110,170,1,0)
      label.draw_line(260,140,170,1,0)

      label.draw_line(180,170,250,1,0)
      label.draw_line(180,200,250,1,0)
      label.draw_line(180,230,250,1,0)
      label.draw_line(180,260,250,1,0)

      label.draw_text(@height.blank? ? "N/A" : "#{@height.to_s} CM",270,56,0,2,1,1,false)
      label.draw_text(@weight.blank? ? "N/A" : "#{@weight.to_s} KG",270,86,0,2,1,1,false)
      # label.draw_text(@who,270,136,0,2,1,1,false)
      @date = (@encounter_datetime.blank? ? (@date.to_date.strftime("%Y-%m-%d") rescue "") : @encounter_datetime )

      label.draw_text((@hiv_test_date.blank? ? @encounter_datetime : @hiv_test_date.to_s),188,146,0,2,1,1,false)
      label.draw_text("#{@syphilis.blank? ? "N/A" : @date.to_s}",188,176,0,2,1,1,false)
      label.draw_text("#{@hb.blank? ? "N/A" : @date.to_s}",188,206,0,2,1,1,false)
      label.draw_text("#{@malaria.blank? ? "N/A" : @date.to_s}",188,236,0,2,1,1,false)
      label.draw_text("#{@blood_group.blank? ? "N/A" : @date.to_s}",188,266,0,2,1,1,false)


      label.draw_text(@hiv_test.to_s,345,146,0,2,1,1,false)
      label.draw_text("#{@syphilis.blank? ? "N/A" : @syphilis.to_s}",325,176,0,2,1,1,false)
      label.draw_text("#{@hb.blank? ? "N/A" : @hb.to_s}",325,206,0,2,1,1,false)
      #label.draw_text(@hb2,325,256,0,2,1,1,false)
      label.draw_text("#{@malaria.blank? ? "N/A" : @malaria.to_s}",325,236,0,2,1,1,false)
      label.draw_text("#{@blood_group.blank? ? "N/A" : @blood_group.to_s}",325,266,0,2,1,1,false)
      #label.draw_text(@malaria,188,226,0,2,1,1,false)

      label.print(1)
      end

      def get_identifier(type = 'National id')
        identifier_type = PatientIdentifierType.find_by_name(type)
        return if identifier_type.blank?
        identifiers = self.patient.patient_identifiers.find_all_by_identifier_type(identifier_type.id)
        return if identifiers.blank?
        identifiers.map{|i|i.identifier}.join(' , ') rescue nil
      end

      def current_weight
        weight = ConceptName.find_by name: "Weight"
        @weight ||= Observation.where(concept_id: weight.concept_id, person_id: @patient.person.id)
                      .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                      .last
                      .value_numeric rescue 0
      end

      def current_height
        height = ConceptName.find_by name: "Height (cm)"
        @height ||= Observation.where(concept_id: height.concept_id, person_id: @patient.person.id)
                      .order(obs_datetime: :desc)
                      .first.value_numeric rescue 0
      end

    end

end