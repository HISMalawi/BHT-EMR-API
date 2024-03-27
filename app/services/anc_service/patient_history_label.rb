# frozen_string_literal: true

module ANCService
    class PatientHistoryLabel
      attr_accessor :patient, :date

      def initialize(patient, date)
        @patient = patient
        @date = date
      end

      def print

        @patient = self.patient rescue nil

        @pregnancies = self.active_range

        @range = []

        @pregnancies = @pregnancies[1]

        @pregnancies.each{|preg|
          @range << preg[0].to_date
        }

        deliveries = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('PARITY').concept_id]).last.answer_string.squish rescue nil

        @deliveries = deliveries.to_i rescue deliveries if deliveries

        @deliveries = @deliveries + (@range.length > 0 ? @range.length - 1 : @range.length) if !@deliveries.nil?

        gravida = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('GRAVIDA').concept_id]).last.answer_string.squish rescue nil

        @gravida = gravida.to_i rescue gravida

        @multipreg = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('MULTIPLE GESTATION').concept_id]).last.answer_string.squish rescue nil

        abortions = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).last.answer_string.squish rescue nil

        @abortions = abortions.to_i rescue abortions

	      still_births_concepts = ConceptName.find_by_sql("SELECT concept_id FROM concept_name where name like '%still birth%'").collect{|c| c.concept_id}.compact

        @stillbirths = Observation.where(["person_id = ? AND concept_id = ? AND (value_coded IN (?) OR value_text like '%still birth%')", @patient.id,
          ConceptName.find_by_name('Condition at Birth').concept_id, still_births_concepts]).last.answer_string.squish rescue nil

        @csections = Observation.where(["person_id = ? AND (concept_id = ? AND value_coded = ?)", @patient.id,
          ConceptName.find_by_name('Caesarean section').concept_id, ConceptName.find_by_name('Yes').concept_id]).length rescue nil

        @csections = Observation.where(["person_id = ? AND (value_coded = ? OR value_text REGEXP ?)", @patient.id,
          ConceptName.find_by_name('Caesarean Section').concept_id, 'Caesarean section']).length rescue nil if ((!(@csections > 0)) rescue true)

        @vacuum = Observation.where(["person_id = ? AND (value_coded = ? OR value_text = ?)", @patient.id,
          ConceptName.find_by_name('Vacuum extraction delivery').concept_id, "Vacuum extraction delivery"
          ]).length rescue nil

        @symphosio = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).last.answer_string.squish rescue nil

        @haemorrhage = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('HEMORRHAGE').concept_id]).last.answer_string.squish rescue nil

        @preeclampsia = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).last.answer_string.squish rescue nil

        @asthma = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('ASTHMA').concept_id]).last.answer_string.squish.upcase rescue nil

        @hyper = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('HYPERTENSION').concept_id]).last.answer_string.squish.upcase rescue nil

        @diabetes = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('DIABETES').concept_id]).last.answer_string.squish.upcase rescue nil

        @epilepsy = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('EPILEPSY').concept_id]).last.answer_string.squish.upcase rescue nil

        @renal = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('RENAL DISEASE').concept_id]).last.answer_string.squish.upcase rescue nil

        @fistula = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('FISTULA REPAIR').concept_id]).last.answer_string.squish.upcase rescue nil

        @deform = Observation.where(["person_id = ? AND concept_id = ?", @patient.id,
          ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).last.answer_string.squish.upcase rescue nil

        @surgicals = Observation.where(["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.where(["patient_id = ? AND encounter_type = ?",
              @patient.id, EncounterType.find_by_name("SURGICAL HISTORY").id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('PROCEDURE DONE').concept_id]).collect{|o|
        "#{o.answer_string.squish} (#{o.obs_datetime.strftime('%d-%b-%Y')})"} rescue []

        @age = self.age rescue 0

        label = ZebraPrinter::StandardLabel.new

        label.draw_text("Obstetric History",28,8,0,1,1,2,false)
        label.draw_text("Medical History",400,8,0,1,1,2,false)
        label.draw_text("Refer",750,8,0,1,1,2,true)
        label.draw_line(25,39,172,1,0)
        label.draw_line(400,39,152,1,0)
        label.draw_text("Gravida",28,59,0,2,1,1,false)
        label.draw_text("Asthma",400,59,0,2,1,1,false)
        label.draw_text("Deliveries",28,89,0,2,1,1,false)
        label.draw_text("Hypertension",400,89,0,2,1,1,false)
        label.draw_text("Abortions",28,119,0,2,1,1,false)
        label.draw_text("Diabetes",400,119,0,2,1,1,false)
        label.draw_text("Still Births",28,149,0,2,1,1,false)
        label.draw_text("Epilepsy",400,149,0,2,1,1,false)
        label.draw_text("Vacuum Extraction",28,179,0,2,1,1,false)
        label.draw_text("Renal Disease",400,179,0,2,1,1,false)
        label.draw_text("C/Section",28,209,0,2,1,1,false)
        label.draw_text("Fistula Repair",400,209,0,2,1,1,false)
        label.draw_text("Haemorrhage",28,239,0,2,1,1,false)
        label.draw_text("Leg/Spine Deformation",400,239,0,2,1,1,false)
        label.draw_text("Pre-Eclampsia",28,269,0,2,1,1,false)
        label.draw_text("Age",400,269,0,2,1,1,false)
        label.draw_line(250,49,130,1,0)
        label.draw_line(250,49,1,236,0)
        label.draw_line(250,285,130,1,0)
        label.draw_line(380,49,1,236,0)
        label.draw_line(250,79,130,1,0)
        label.draw_line(250,109,130,1,0)
        label.draw_line(250,139,130,1,0)
        label.draw_line(250,169,130,1,0)
        label.draw_line(250,199,130,1,0)
        label.draw_line(250,229,130,1,0)
        label.draw_line(250,259,130,1,0)
        label.draw_line(659,49,130,1,0)
        label.draw_line(659,49,1,236,0)
        label.draw_line(659,285,130,1,0)
        label.draw_line(790,49,1,236,0)
        label.draw_line(659,79,130,1,0)
        label.draw_line(659,109,130,1,0)
        label.draw_line(659,139,130,1,0)
        label.draw_line(659,169,130,1,0)
        label.draw_line(659,199,130,1,0)
        label.draw_line(659,229,130,1,0)
        label.draw_line(659,259,130,1,0)
        label.draw_text("#{@gravida}",280,59,0,2,1,1,false)
        label.draw_text("#{@deliveries}",280,89,0,2,1,1,(((@deliveries > 4) rescue false) ? true : false))
        label.draw_text("#{@abortions}",280,119,0,2,1,1,(@abortions > 1 ? true : false))
        label.draw_text("#{(!@stillbirths.nil? ? (@stillbirths.upcase == "NO" ? "NO" : "YES") : "")}",280,149,0,2,1,1,
            (!@stillbirths.nil? ? (@stillbirths.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@vacuum.nil? ? (@vacuum > 0 ? "YES" : "NO") : "")}",280,179,0,2,1,1,
            (!@vacuum.nil? ? (@vacuum > 0 ? true : false) : false))
        label.draw_text("#{(!@csections.blank? ? (@csections <= 0 ? "NO" : "YES") : "")}",280,209,0,2,1,1,
            (!@csections.blank? ? (@csections <= 0 ? false : true) : false))
        label.draw_text("#{@haemorrhage}",280,239,0,2,1,1,(((@haemorrhage.upcase == "PPH") rescue false) ? true : false))
        label.draw_text("#{(!@preeclampsia.nil? ? (((@preeclampsia.upcase == "NO") rescue false) ? "NO" : "YES") : "")}",280,264,0,2,1,1,
            (!@preeclampsia.nil? ? (@preeclampsia.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@asthma.nil? ? (@asthma.upcase == "NO" ? "NO" : "YES") : "")}",690,59,0,2,1,1,
            (!@asthma.nil? ? (@asthma.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@hyper.nil? ? (@hyper.upcase == "NO" ? "NO" : "YES") : "")}",690,89,0,2,1,1,
            (!@hyper.nil? ? (@hyper.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@diabetes.nil? ? (@diabetes.upcase == "NO" ? "NO" : "YES") : "")}",690,119,0,2,1,1,
            (!@diabetes.nil? ? (@diabetes.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@epilepsy.nil? ? (@epilepsy.upcase == "NO" ? "NO" : "YES") : "")}",690,149,0,2,1,1,
            (!@epilepsy.nil? ? (@epilepsy.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@renal.nil? ? (@renal.upcase == "NO" ? "NO" : "YES") : "")}",690,179,0,2,1,1,
            (!@renal.nil? ? (@renal == "NO" ? false : true) : false))
        label.draw_text("#{(!@fistula.nil? ? (@fistula.upcase == "NO" ? "NO" : "YES") : "")}",690,209,0,2,1,1,
            (!@fistula.nil? ? (@fistula.upcase == "NO" ? false : true) : false))
        label.draw_text("#{(!@deform.nil? ? (@deform.upcase == "NO" ? "NO" : "YES") : "")}",690,239,0,2,1,1,
            (!@deform.nil? ? (@deform == "NO" ? false : true) : false))
        label.draw_text("#{@age}",690,264,0,2,1,1,
            (((@age > 0 && @age < 16) || (@age > 40)) ? true : false))

        label.print(1)

      end

      def active_range(date = Date.today)

        current_range = {}

        active_date = date

        pregnancies = {};

        # active_years = {}

        abortion_check_encounter = self.patient.encounters.where(["encounter_type = ? AND encounter_datetime > ? AND DATE(encounter_datetime) <= ?",
            EncounterType.find_by_name("PREGNANCY STATUS").encounter_type_id, date.to_date - 7.months, date.to_date]).order(["encounter_datetime DESC"]).first rescue nil

        aborted = abortion_check_encounter.observations.collect{|ob| ob.answer_string.downcase.strip if ob.concept_id == ConceptName.find_by_name("PREGNANCY ABORTED").concept_id}.compact.include?("yes")  rescue false

        date_aborted = abortion_check_encounter.observations.find_by_concept_id(ConceptName.find_by_name("DATE OF SURGERY").concept_id).answer_string rescue nil
        recent_lmp = self.find_by_sql(["SELECT * from obs WHERE person_id = #{self.patient.id} AND concept_id =
                            (SELECT concept_id FROM concept_name WHERE name = 'DATE OF LAST MENSTRUAL PERIOD' LIMIT 1)"]).last.answer_string.squish.to_date rescue nil

        self.patient.encounters.order(["encounter_datetime DESC"]).each{|e|
          if e.name == "CURRENT PREGNANCY" && !pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")]
            pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")] = {}

            e.observations.each{|o|
              concept = o.concept.name rescue nil
              if concept
                # if !active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")]
                if o.concept_id == (ConceptName.find_by_name("DATE OF LAST MENSTRUAL PERIOD").concept_id rescue nil)
                  pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")]["DATE OF LAST MENSTRUAL PERIOD"] = o.answer_string.squish
                  # active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")] = true
                end
                # end
              end
            }
          end
        }

        # pregnancies = pregnancies.delete_if{|x, v| v == {}}

        pregnancies.each{|preg|
          if preg[1]["DATE OF LAST MENSTRUAL PERIOD"]
            preg[1]["START"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date
            preg[1]["END"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date + 7.day + 45.week # 9.month
          else
            preg[1]["START"] = preg[0].to_date
            preg[1]["END"] = preg[0].to_date + 7.day + 45.week # 9.month
          end

          if active_date >= preg[1]["START"] && active_date <= preg[1]["END"]
            current_range["START"] = preg[1]["START"]
            current_range["END"] = preg[1]["END"]
          end
        }

        if recent_lmp.present?
          current_range["START"] = recent_lmp
          current_range["END"] = current_range["START"] + 9.months
        end

        if (abortion_check_encounter.present? && aborted && date_aborted.present? && current_range["START"].to_date < date_aborted.to_date rescue false)

              current_range["START"] = date_aborted.to_date + 10.days
              current_range["END"] = current_range["START"] + 9.months
        end

        current_range["END"] = current_range["START"] + 7.day + 45.week unless ((current_range["START"]).to_date.blank? rescue true)

        return [current_range, pregnancies]
      end

      #private

      def age
        person = @patient.person rescue nil
        return 0 if person.blank?

        today = @date
        # This code which better accounts for leap years
        patient_age = (today.year - person.birthdate.year) + \
         ((today.month - person.birthdate.month) + \
          ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

        # If the birthdate was estimated this year, we round up the age, that way if
        # it is March and the patient says they are 25, they stay 25 (not become 24)
        birth_date=person.birthdate
        estimate=person.birthdate_estimated==1
        patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  \
          && today.month < birth_date.month && \
            person.date_created.year == today.year) ? 1 : 0

        patient_age
      end

    end
end
