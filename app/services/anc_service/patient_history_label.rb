# frozen_string_literal: true

module AncService
  class PatientHistoryLabel
    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def print
      @patient = begin
        patient
      rescue StandardError
        nil
      end

      @pregnancies = active_range

      @range = []

      @pregnancies = @pregnancies[1]

      @pregnancies.each do |preg|
        @range << preg[0].to_date
      end

      deliveries = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('PARITY').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      if deliveries
        @deliveries = begin
          deliveries.to_i
        rescue StandardError
          deliveries
        end
      end

      @deliveries += (!@range.empty? ? @range.length - 1 : @range.length) unless @deliveries.nil?

      gravida = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('GRAVIDA').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @gravida = begin
        gravida.to_i
      rescue StandardError
        gravida
      end

      @multipreg = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('MULTIPLE GESTATION').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      abortions = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @abortions = begin
        abortions.to_i
      rescue StandardError
        abortions
      end

      still_births_concepts = ConceptName.find_by_sql("SELECT concept_id FROM concept_name where name like '%still birth%'").collect(&:concept_id).compact

      @stillbirths = begin
        Observation.where(["person_id = ? AND concept_id = ? AND (value_coded IN (?) OR value_text like '%still birth%')", @patient.id,
                           ConceptName.find_by_name('Condition at Birth').concept_id, still_births_concepts]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @csections = begin
        Observation.where(['person_id = ? AND (concept_id = ? AND value_coded = ?)', @patient.id,
                           ConceptName.find_by_name('Caesarean section').concept_id, ConceptName.find_by_name('Yes').concept_id]).length
      rescue StandardError
        nil
      end

      if begin
        @csections <= 0
      rescue StandardError
        true
      end
        @csections = begin
          Observation.where(['person_id = ? AND (value_coded = ? OR value_text REGEXP ?)', @patient.id,
                             ConceptName.find_by_name('Caesarean Section').concept_id, 'Caesarean section']).length
        rescue StandardError
          nil
        end
      end

      @vacuum = begin
        Observation.where(['person_id = ? AND (value_coded = ? OR value_text = ?)', @patient.id,
                           ConceptName.find_by_name('Vacuum extraction delivery').concept_id, 'Vacuum extraction delivery']).length
      rescue StandardError
        nil
      end

      @symphosio = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @haemorrhage = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('HEMORRHAGE').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @preeclampsia = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      @asthma = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('ASTHMA').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @hyper = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('HYPERTENSION').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @diabetes = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('DIABETES').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @epilepsy = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('EPILEPSY').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @renal = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('RENAL DISEASE').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @fistula = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('FISTULA REPAIR').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @deform = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).last.answer_string.squish.upcase
      rescue StandardError
        nil
      end

      @surgicals = begin
        Observation.where(['person_id = ? AND encounter_id IN (?) AND concept_id = ?',
                           @patient.id, Encounter.where(['patient_id = ? AND encounter_type = ?',
                                                         @patient.id, EncounterType.find_by_name('SURGICAL HISTORY').id]).collect(&:encounter_id),
                           ConceptName.find_by_name('PROCEDURE DONE').concept_id]).collect do |o|
          "#{o.answer_string.squish} (#{o.obs_datetime.strftime('%d-%b-%Y')})"
        end
      rescue StandardError
        []
      end

      @age = begin
        age
      rescue StandardError
        0
      end

      label = ZebraPrinter::StandardLabel.new

      label.draw_text('Obstetric History', 28, 8, 0, 1, 1, 2, false)
      label.draw_text('Medical History', 400, 8, 0, 1, 1, 2, false)
      label.draw_text('Refer', 750, 8, 0, 1, 1, 2, true)
      label.draw_line(25, 39, 172, 1, 0)
      label.draw_line(400, 39, 152, 1, 0)
      label.draw_text('Gravida', 28, 59, 0, 2, 1, 1, false)
      label.draw_text('Asthma', 400, 59, 0, 2, 1, 1, false)
      label.draw_text('Deliveries', 28, 89, 0, 2, 1, 1, false)
      label.draw_text('Hypertension', 400, 89, 0, 2, 1, 1, false)
      label.draw_text('Abortions', 28, 119, 0, 2, 1, 1, false)
      label.draw_text('Diabetes', 400, 119, 0, 2, 1, 1, false)
      label.draw_text('Still Births', 28, 149, 0, 2, 1, 1, false)
      label.draw_text('Epilepsy', 400, 149, 0, 2, 1, 1, false)
      label.draw_text('Vacuum Extraction', 28, 179, 0, 2, 1, 1, false)
      label.draw_text('Renal Disease', 400, 179, 0, 2, 1, 1, false)
      label.draw_text('C/Section', 28, 209, 0, 2, 1, 1, false)
      label.draw_text('Fistula Repair', 400, 209, 0, 2, 1, 1, false)
      label.draw_text('Haemorrhage', 28, 239, 0, 2, 1, 1, false)
      label.draw_text('Leg/Spine Deformation', 400, 239, 0, 2, 1, 1, false)
      label.draw_text('Pre-Eclampsia', 28, 269, 0, 2, 1, 1, false)
      label.draw_text('Age', 400, 269, 0, 2, 1, 1, false)
      label.draw_line(250, 49, 130, 1, 0)
      label.draw_line(250, 49, 1, 236, 0)
      label.draw_line(250, 285, 130, 1, 0)
      label.draw_line(380, 49, 1, 236, 0)
      label.draw_line(250, 79, 130, 1, 0)
      label.draw_line(250, 109, 130, 1, 0)
      label.draw_line(250, 139, 130, 1, 0)
      label.draw_line(250, 169, 130, 1, 0)
      label.draw_line(250, 199, 130, 1, 0)
      label.draw_line(250, 229, 130, 1, 0)
      label.draw_line(250, 259, 130, 1, 0)
      label.draw_line(659, 49, 130, 1, 0)
      label.draw_line(659, 49, 1, 236, 0)
      label.draw_line(659, 285, 130, 1, 0)
      label.draw_line(790, 49, 1, 236, 0)
      label.draw_line(659, 79, 130, 1, 0)
      label.draw_line(659, 109, 130, 1, 0)
      label.draw_line(659, 139, 130, 1, 0)
      label.draw_line(659, 169, 130, 1, 0)
      label.draw_line(659, 199, 130, 1, 0)
      label.draw_line(659, 229, 130, 1, 0)
      label.draw_line(659, 259, 130, 1, 0)
      label.draw_text(@gravida.to_s, 280, 59, 0, 2, 1, 1, false)
      label.draw_text(@deliveries.to_s, 280, 89, 0, 2, 1, 1, begin
        (@deliveries > 4)
      rescue StandardError
        false ? true : false
      end)
      label.draw_text(@abortions.to_s, 280, 119, 0, 2, 1, 1, (@abortions > 1))
      label.draw_text((if !@stillbirths.nil?
                         @stillbirths.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 280, 149, 0, 2, 1, 1,
                      (if !@stillbirths.nil?
                         @stillbirths.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@vacuum.nil?
                         @vacuum.positive? ? 'YES' : 'NO'
                       else
                         ''
                       end).to_s, 280, 179, 0, 2, 1, 1,
                      (if !@vacuum.nil?
                         @vacuum.positive? ? true : false
                       else
                         false
                       end))
      label.draw_text((if !@csections.blank?
                         @csections <= 0 ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 280, 209, 0, 2, 1, 1,
                      (if !@csections.blank?
                         @csections.positive?
                       else
                         false
                       end))
      label.draw_text(@haemorrhage.to_s, 280, 239, 0, 2, 1, 1,
                      begin
                        (@haemorrhage.upcase == 'PPH')
                      rescue StandardError
                        false ? true : false
                      end)
      label.draw_text((if !@preeclampsia.nil?
                         begin
                           (@preeclampsia.upcase == 'NO')
                         rescue StandardError
                           false ? 'NO' : 'YES'
                         end
                       else
                         ''
                       end).to_s, 280, 264, 0, 2, 1, 1,
                      (if !@preeclampsia.nil?
                         @preeclampsia.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@asthma.nil?
                         @asthma.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 59, 0, 2, 1, 1,
                      (if !@asthma.nil?
                         @asthma.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@hyper.nil?
                         @hyper.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 89, 0, 2, 1, 1,
                      (if !@hyper.nil?
                         @hyper.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@diabetes.nil?
                         @diabetes.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 119, 0, 2, 1, 1,
                      (if !@diabetes.nil?
                         @diabetes.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@epilepsy.nil?
                         @epilepsy.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 149, 0, 2, 1, 1,
                      (if !@epilepsy.nil?
                         @epilepsy.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@renal.nil?
                         @renal.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 179, 0, 2, 1, 1,
                      (if !@renal.nil?
                         @renal != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@fistula.nil?
                         @fistula.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 209, 0, 2, 1, 1,
                      (if !@fistula.nil?
                         @fistula.upcase != 'NO'
                       else
                         false
                       end))
      label.draw_text((if !@deform.nil?
                         @deform.upcase == 'NO' ? 'NO' : 'YES'
                       else
                         ''
                       end).to_s, 690, 239, 0, 2, 1, 1,
                      (if !@deform.nil?
                         @deform != 'NO'
                       else
                         false
                       end))
      label.draw_text(@age.to_s, 690, 264, 0, 2, 1, 1,
                      ((@age.positive? && @age < 16) || (@age > 40) ? true : false))

      label.print(1)
    end

    def active_range(date = Date.today)
      current_range = {}

      active_date = date

      pregnancies = {}

      # active_years = {}

      abortion_check_encounter = begin
        patient.encounters.where(['encounter_type = ? AND encounter_datetime > ? AND DATE(encounter_datetime) <= ?',
                                  EncounterType.find_by_name('PREGNANCY STATUS').encounter_type_id, date.to_date - 7.months, date.to_date]).order(['encounter_datetime DESC']).first
      rescue StandardError
        nil
      end

      aborted = begin
        abortion_check_encounter.observations.collect do |ob|
          ob.answer_string.downcase.strip if ob.concept_id == ConceptName.find_by_name('PREGNANCY ABORTED').concept_id
        end.compact.include?('yes')
      rescue StandardError
        false
      end

      date_aborted = begin
        abortion_check_encounter.observations.find_by_concept_id(ConceptName.find_by_name('DATE OF SURGERY').concept_id).answer_string
      rescue StandardError
        nil
      end
      recent_lmp = begin
        find_by_sql(["SELECT * from obs WHERE person_id = #{patient.id} AND concept_id =
                            (SELECT concept_id FROM concept_name WHERE name = 'DATE OF LAST MENSTRUAL PERIOD' LIMIT 1)"]).last.answer_string.squish.to_date
      rescue StandardError
        nil
      end

      patient.encounters.order(['encounter_datetime DESC']).each do |e|
        next unless e.name == 'CURRENT PREGNANCY' && !pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')]

        pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')] = {}

        e.observations.each do |o|
          concept = begin
            o.concept.name
          rescue StandardError
            nil
          end
          next unless concept

          # if !active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")]
          next unless o.concept_id == begin
            ConceptName.find_by_name('DATE OF LAST MENSTRUAL PERIOD').concept_id
          rescue StandardError
            nil
          end

          pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')]['DATE OF LAST MENSTRUAL PERIOD'] =
            o.answer_string.squish
          # active_years[e.encounter_datetime.beginning_of_quarter.strftime("%Y-%m-%d")] = true
          # end
        end
      end

      # pregnancies = pregnancies.delete_if{|x, v| v == {}}

      pregnancies.each do |preg|
        if preg[1]['DATE OF LAST MENSTRUAL PERIOD']
          preg[1]['START'] = preg[1]['DATE OF LAST MENSTRUAL PERIOD'].to_date
          preg[1]['END'] = preg[1]['DATE OF LAST MENSTRUAL PERIOD'].to_date + 7.day + 45.week # 9.month
        else
          preg[1]['START'] = preg[0].to_date
          preg[1]['END'] = preg[0].to_date + 7.day + 45.week # 9.month
        end

        if active_date >= preg[1]['START'] && active_date <= preg[1]['END']
          current_range['START'] = preg[1]['START']
          current_range['END'] = preg[1]['END']
        end
      end

      if recent_lmp.present?
        current_range['START'] = recent_lmp
        current_range['END'] = current_range['START'] + 9.months
      end

      if begin
        abortion_check_encounter.present? && aborted && date_aborted.present? && current_range['START'].to_date < date_aborted.to_date
      rescue StandardError
        false
      end

        current_range['START'] = date_aborted.to_date + 10.days
        current_range['END'] = current_range['START'] + 9.months
      end

      unless begin
        (current_range['START']).to_date.blank?
      rescue StandardError
        true
      end
        current_range['END'] =
          current_range['START'] + 7.day + 45.week
      end

      [current_range, pregnancies]
    end

    # private

    def age
      person = begin
        @patient.person
      rescue StandardError
        nil
      end
      return 0 if person.blank?

      today = @date
      # This code which better accounts for leap years
      patient_age = (today.year - person.birthdate.year) + \
                    (if ((today.month - person.birthdate.month) + \
                     ((today.day - person.birthdate.day).negative? ? -1 : 0)).negative?
                       -1
                     else
                       0
                     end)

      # If the birthdate was estimated this year, we round up the age, that way if
      # it is March and the patient says they are 25, they stay 25 (not become 24)
      birth_date = person.birthdate
      estimate = person.birthdate_estimated == 1
      patient_age += if estimate && birth_date.month == 7 && birth_date.day == 1  \
        && today.month < birth_date.month && \
                        person.date_created.year == today.year
                       1
                     else
                       0
                     end

      patient_age
    end
  end
end
