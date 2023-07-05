# frozen_string_literal: true

module AncService
  class PatientVisitLabel
    attr_accessor :patient, :date

    PROGRAM = Program.find_by name: 'ANC PROGRAM'

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def print
      print1 + print2 + detailed_obstetric_history_label
    end

    def print1
      visit = AncService::PatientVisit.new patient, date
      return unless visit

      @current_range = visit.active_range(@date.to_date)

      encounters = {}

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        encounters[e.encounter_datetime.strftime('%d/%b/%Y')] =
          { 'USER' => PersonName.find_by(person_id: e.provider_id) }
      end

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        next if e.type.nil?

        encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase] = begin
          {}
        rescue StandardError
          ''
        end
      end

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        next if e.type.nil?

        # rescue nil
        e.observations.each do |o|
          concept = ConceptName.find_by concept_id: o.concept_id
          value = getObsValue(o)
          unless concept.name.blank?
            if concept.name.upcase == 'DIAGNOSIS' && encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase]
              encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] += "; #{value}"
            else
              encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] =
                value
              if concept.name.upcase == 'PLANNED DELIVERY PLACE'
                @current_range[0]['PLANNED DELIVERY PLACE'] = value
              elsif concept.name.upcase == 'MOSQUITO NET'
                @current_range[0]['MOSQUITO NET'] = value
              end
            end
          end
        end
      end

      @drugs = {}
      @other_drugs = {}
      main_drugs = %w[TD SP Fefol Albendazole]

      @patient.encounters.where(['(encounter_type = ? OR encounter_type = ?) AND encounter_datetime >= ? AND encounter_datetime <= ?',
                                 EncounterType.find_by_name('TREATMENT').id, EncounterType.find_by_name('DISPENSING').id,
                                 @current_range[0]['START'], @current_range[0]['END']]).order('encounter_datetime DESC').each do |e|
        unless @drugs[e.encounter_datetime.strftime('%d/%b/%Y')]
          @drugs[e.encounter_datetime.strftime('%d/%b/%Y')] =
            {}
        end
        unless @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')]
          @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')] =
            {}
        end
        e.orders.each do |o|
          drug_name = begin
            if o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)
              "#{o.drug_order.drug.name[0,
                                        o.drug_order.drug.name.index(' ')]} #{o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0]}"
            else
              o.drug_order.drug.name[0, o.drug_order.drug.name.index(' ')]
            end
          rescue StandardError
            o.drug_order.drug.name
          end

          if begin
            main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(' ')])
          rescue StandardError
            false
          end

            @drugs[e.encounter_datetime.strftime('%d/%b/%Y')][o.drug_order.drug.name[0,
                                                                                     o.drug_order.drug.name.index(' ')]] = o.drug_order.quantity # amount_needed
          else

            @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')][drug_name] = o.drug_order.quantity # amount_needed
          end
        end
      end

      label = ZebraPrinter::StandardLabel.new

      label.draw_line(20, 25, 800, 2, 0)
      label.draw_line(20, 25, 2, 280, 0)
      label.draw_line(20, 305, 800, 2, 0)
      label.draw_line(805, 25, 2, 280, 0)
      label.draw_text('Visit Summary', 40, 33, 0, 1, 1, 2, false)
      label.draw_text("Last Menstrual Period: #{begin
        @current_range[0]['START'].to_date.strftime('%d/%b/%Y')
      rescue StandardError
        ''
      end}",
                      40, 76, 0, 2, 1, 1, false)
      label.draw_text(
        "Expected Date of Delivery: #{begin
          @current_range[0]['END'].to_date.strftime('%d/%b/%Y')
        rescue StandardError
          ''
        end}", 40, 99, 0, 2, 1, 1, false
      )
      label.draw_line(28, 60, 132, 1, 0)
      label.draw_line(20, 130, 800, 2, 0)
      label.draw_line(20, 190, 800, 2, 0)
      label.draw_text('Gest.', 41, 140, 0, 2, 1, 1, false)
      label.draw_text('Fundal', 99, 140, 0, 2, 1, 1, false)
      label.draw_text('Pos./', 178, 140, 0, 2, 1, 1, false)
      label.draw_text('Fetal', 259, 140, 0, 2, 1, 1, false)
      label.draw_text('Weight', 339, 140, 0, 2, 1, 1, false)
      label.draw_text('(kg)', 339, 158, 0, 2, 1, 1, false)
      label.draw_text('BP', 435, 140, 0, 2, 1, 1, false)
      label.draw_text('Urine', 499, 138, 0, 2, 1, 1, false)
      label.draw_text('Prote-', 499, 156, 0, 2, 1, 1, false)
      label.draw_text('in', 505, 174, 0, 2, 1, 1, false)
      label.draw_text('SP', 595, 140, 0, 2, 1, 1, false)
      label.draw_text('(tabs)', 575, 158, 0, 2, 1, 1, false)
      label.draw_text('FeFo', 664, 140, 0, 2, 1, 1, false)
      label.draw_text('(tabs)', 655, 158, 0, 2, 1, 1, false)
      label.draw_text('Albe.', 740, 140, 0, 2, 1, 1, false)
      label.draw_text('(tabs)', 740, 156, 0, 2, 1, 1, false)
      label.draw_text('Age', 41, 158, 0, 2, 1, 1, false)
      label.draw_text('Height', 99, 158, 0, 2, 1, 1, false)
      label.draw_text('Pres.', 178, 158, 0, 2, 1, 1, false)
      label.draw_text('Heart', 259, 158, 0, 2, 1, 1, false)
      label.draw_line(90, 130, 2, 175, 0)
      label.draw_line(170, 130, 2, 175, 0)
      label.draw_line(250, 130, 2, 175, 0)
      label.draw_line(330, 130, 2, 175, 0)
      label.draw_line(410, 130, 2, 175, 0)
      label.draw_line(490, 130, 2, 175, 0)
      label.draw_line(570, 130, 2, 175, 0)
      label.draw_line(650, 130, 2, 175, 0)
      label.draw_line(730, 130, 2, 175, 0)

      @i = 0

      out = []

      # raise encounters.inspect

      encounters.each do |v, k|
        out << [k['ANC VISIT TYPE']['REASON FOR VISIT'].to_i, v]
      rescue StandardError
        []
      end
      out = out.sort.compact

      # raise out.to_yaml

      out.each do |_key, element|
        encounters[element]

        @i += 1

        next unless element == @date.to_date.strftime('%d/%b/%Y')

        visit = encounters[element]['ANC VISIT TYPE']['REASON FOR VISIT'].to_i

        label.draw_text("Visit No: #{visit}", 250, 33, 0, 1, 1, 2, false)
        label.draw_text("Visit Date: #{element}", 450, 33, 0, 1, 1, 2, false)

        fundal_height = begin
          encounters[element]['ANC EXAMINATION']['FUNDUS'].to_i
        rescue StandardError
          0
        end

        gestation_weeks = begin
          getEquivFundalWeeks(fundal_height)
        rescue StandardError
          ''
        end

        gest = gestation_weeks.to_s

        label.draw_text(gest, 41, 200, 0, 2, 1, 1, false)

        label.draw_text('wks', 41, 226, 0, 2, 1, 1, false)

        fund = begin
          (fundal_height <= 0 ? '?' : "#{fundal_height}(cm)")
        rescue StandardError
          ''
        end

        label.draw_text(fund, 99, 200, 0, 2, 1, 1, false)

        posi = begin
          encounters[element]['ANC EXAMINATION']['POSITION']
        rescue StandardError
          ''
        end
        pres = begin
          encounters[element]['ANC EXAMINATION']['PRESENTATION']
        rescue StandardError
          ''
        end

        posipres = paragraphate(posi.to_s + pres.to_s, 5, 5)

        (0..(posipres.length)).each do |u|
          label.draw_text(posipres[u].to_s, 178, (200 + (13 * u)), 0, 2, 1, 1, false)
        end

        fet = begin
          (if encounters[element]['ANC EXAMINATION']['FETAL HEART BEAT'].humanize == 'Unknown'
             '?'
           else
             encounters[element]['ANC EXAMINATION']['FETAL HEART BEAT'].humanize
           end).gsub(/Fetal\smovement\sfelt\s\(fmf\)/i, 'FMF')
        rescue StandardError
          ''
        end

        fet = paragraphate(fet, 5, 5)

        (0..(fet.length)).each do |f|
          label.draw_text(fet[f].to_s, 259, (200 + (13 * f)), 0, 2, 1, 1, false)
        end

        wei = begin
          (if encounters[element]['VITALS']['WEIGHT (KG)'].to_i <= 0
             '?'
           else
             ((if encounters[element]['VITALS']['WEIGHT (KG)'].to_s.match(/\.[1-9]/)
                 encounters[element]['VITALS']['WEIGHT (KG)']
               else
                 encounters[element]['VITALS']['WEIGHT (KG)'].to_i
               end))
           end)
        rescue StandardError
          ''
        end

        label.draw_text(wei.to_s, 339, 200, 0, 2, 1, 1, false)

        sbp = begin
          (if encounters[element]['VITALS']['SYSTOLIC BLOOD PRESSURE'].to_i <= 0
             '?'
           else
             encounters[element]['VITALS']['SYSTOLIC BLOOD PRESSURE'].to_i
           end)
        rescue StandardError
          '?'
        end

        dbp = begin
          (if encounters[element]['VITALS']['DIASTOLIC BLOOD PRESSURE'].to_i <= 0
             '?'
           else
             encounters[element]['VITALS']['DIASTOLIC BLOOD PRESSURE'].to_i
           end)
        rescue StandardError
          '?'
        end

        bp = paragraphate("#{sbp}/#{dbp}", 4, 3)

        (0..(bp.length)).each do |u|
          label.draw_text(bp[u].to_s, 420, (200 + (18 * u)), 0, 2, 1, 1, false)
        end

        uri = begin
          encounters[element]['LAB RESULTS']['URINE PROTEIN']
        rescue StandardError
          ''
        end

        uri = paragraphate(uri, 5, 5)

        (0..(uri.length)).each do |u|
          label.draw_text(uri[u].to_s, 498, (200 + (18 * u)), 0, 2, 1, 1, false)
        end

        sp = begin
          (@drugs[element]['SP'].to_i.positive? ? @drugs[element]['SP'].to_i : '')
        rescue StandardError
          ''
        end

        label.draw_text(sp, 595, 200, 0, 2, 1, 1, false)

        @ferrous_fefol = begin
          @other_drugs.keys.collect do |date|
            @other_drugs[date].keys.collect do |key|
              @other_drugs[date][key] if begin
                (@other_drugs[date][key].to_i.positive? && (key.downcase.strip == 'ferrous'))
              rescue StandardError
                false
              end
            end
          end.compact.first.to_s
        rescue StandardError
          ''
        end

        fefo = begin
          (@drugs[element]['Fefol'].to_i.positive? ? @drugs[element]['Fefol'].to_i : '')
        rescue StandardError
          ''
        end

        fefo = begin
          (fefo.to_i + @ferrous_fefol.to_i)
        rescue StandardError
          fefo
        end
        fefo = '' if begin
          fefo.to_i.zero?
        rescue StandardError
          false
        end

        label.draw_text(fefo.to_s, 664, 200, 0, 2, 1, 1, false)

        albe = begin
          (@drugs[element]['Albendazole'].to_i.positive? ? @drugs[element]['Albendazole'].to_i : '')
        rescue StandardError
          ''
        end

        label.draw_text(albe.to_s, 740, 200, 0, 2, 1, 1, false)
      end

      @encounters = encounters

      label.print(1)
    end

    def print2
      visit = AncService::PatientVisit.new patient, date
      return unless visit

      @current_range = visit.active_range(@date.to_date)

      # raise @current_range.to_yaml

      encounters = {}

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        encounters[e.encounter_datetime.strftime('%d/%b/%Y')] =
          { 'USER' => PersonName.find_by(person_id: e.provider_id) }
      end

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        next if e.type.nil?

        encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase] = begin
          {}
        rescue StandardError
          ''
        end
      end

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        # rescue nil
        e.observations.each do |o|
          concept = begin
            ConceptName.find_by concept_id: o.concept_id
          rescue StandardError
            nil
          end
          value = getObsValue(o)
          unless concept.blank?
            if concept.name.upcase == 'DIAGNOSIS' && encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase]
              encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] += "; #{value}"
            else
              unless e.type.nil?
                encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] =
                  begin
                    value
                  rescue StandardError
                    ''
                  end
              end
              if concept.name.upcase == 'PLANNED DELIVERY PLACE'
                @current_range[0]['PLANNED DELIVERY PLACE'] = value
              elsif concept.name.upcase == 'MOSQUITO NET'
                @current_range[0]['MOSQUITO NET'] = value
              end
            end
          end
        end
      end

      @drugs = {}
      @other_drugs = {}
      main_drugs = %w[TD SP Fefol Albendazole]

      @patient.encounters.where(["(encounter_type = ? OR encounter_type = ?) AND encounter_datetime >= ? AND encounter_datetime <= ?
            AND program_id = ?", EncounterType.find_by_name('TREATMENT').id, EncounterType.find_by_name('DISPENSING').id,
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).order('encounter_datetime DESC').each do |e|
        unless @drugs[e.encounter_datetime.strftime('%d/%b/%Y')]
          @drugs[e.encounter_datetime.strftime('%d/%b/%Y')] =
            {}
        end
        unless @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')]
          @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')] =
            {}
        end
        e.orders.each do |o|
          drug_name = begin
            if o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)
              "#{o.drug_order.drug.name[0,
                                        o.drug_order.drug.name.index(' ')]} #{o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0]}"
            else
              o.drug_order.drug.name[0, o.drug_order.drug.name.index(' ')]
            end
          rescue StandardError
            o.drug_order.drug.name
          end

          main_drugs_passed = begin
            main_drugs.include?(o.drug_order.drug.name[0,
                                                       o.drug_order.drug.name.index(' ')])
          rescue StandardError
            false
          end

          if main_drugs_passed
            @drugs[e.encounter_datetime.strftime('%d/%b/%Y')][o.drug_order.drug.name[0,
                                                                                     o.drug_order.drug.name.index(' ')]] = o.drug_order.quantity
          else

            @other_drugs[e.encounter_datetime.strftime('%d/%b/%Y')][drug_name] = o.drug_order.quantity # amount_needed
          end
        end
      end

      label = ZebraPrinter::StandardLabel.new

      label.draw_line(20, 25, 800, 2, 0)
      label.draw_line(20, 25, 2, 280, 0)
      label.draw_line(20, 305, 800, 2, 0)
      label.draw_line(805, 25, 2, 280, 0)

      label.draw_line(20, 130, 800, 2, 0)
      label.draw_line(20, 190, 800, 2, 0)

      label.draw_line(160, 130, 2, 175, 0)
      label.draw_line(364, 130, 2, 175, 0)
      label.draw_line(594, 130, 2, 175, 0)
      label.draw_line(706, 130, 2, 175, 0)
      label.draw_text("Planned Delivery Place: #{begin
        @current_range[0]['PLANNED DELIVERY PLACE']
      rescue StandardError
        ''
      end}", 40, 66, 0, 2,
                      1, 1, false)
      label.draw_text("Bed Net Given: #{begin
        @current_range[0]['MOSQUITO NET']
      rescue StandardError
        ''
      end}", 40, 99, 0, 2, 1, 1, false)
      label.draw_text('', 28, 138, 0, 2, 1, 1, false)
      label.draw_text('TD', 75, 156, 0, 2, 1, 1, false)

      label.draw_text('Diagnosis', 170, 140, 0, 2, 1, 1, false)
      label.draw_text('Medication/Outcome', 370, 140, 0, 2, 1, 1, false)
      label.draw_text('Next Vis.', 600, 140, 0, 2, 1, 1, false)
      label.draw_text('Date', 622, 158, 0, 2, 1, 1, false)
      label.draw_text('Provider', 710, 140, 0, 2, 1, 1, false)

      @i = 0

      out = []

      encounters.each do |v, k|
        out << [k['ANC VISIT TYPE']['REASON FOR VISIT'].to_i, v]
      rescue StandardError
        []
      end
      out = out.sort.compact

      # raise out.to_yaml

      out.each do |_key, element|
        encounter = encounters[element]
        @i += 1

        next unless element == @date.to_date.strftime('%d/%b/%Y')

        td = begin
          ((@drugs[element]['TD']).positive? ? 1 : '')
        rescue StandardError
          ''
        end

        label.draw_text(td.to_s, 28, 200, 0, 2, 1, 1, false)

        sign = ''
        diagnosis = ['malaria', 'anaemia', 'pre-eclampsia', 'vaginal bleeding', 'early rupture of membranes',
                     'premature labour', 'pneumonia', 'verruca planus, extensive']

        anc_exam = encounter['ANC EXAMINATION']

        unless anc_exam.blank?
          anc_exam.each do |key, _value|
            sign += "#{key.downcase}, " if diagnosis.include?(key.downcase)
          end
        end

        sign = paragraphate(sign.to_s, 13, 5)

        (0..(sign.length)).each do |m|
          label.draw_text(sign[m].to_s, 175, (200 + (25 * m)), 0, 2, 1, 1, false)
        end

        med = begin
          "#{encounters[element]['UPDATE OUTCOME']['OUTCOME'].humanize}; "
        rescue StandardError
          ''
        end
        begin
          if @other_drugs[element].length.positive?
            oth = @other_drugs[element].collect do |d, v|
              "#{d}: #{v.to_s.match(/\.[1-9]/) ? v : v.to_i}"
            end.join('; ')
          end
        rescue StandardError
          ''
        end

        med = paragraphate(med.to_s + oth.to_s, 17, 5)

        (0..(med.length)).each do |m|
          label.draw_text(med[m].to_s, 370, (200 + (18 * m)), 0, 2, 1, 1, false)
        end
        nex = begin
          encounters[element]['APPOINTMENT']['APPOINTMENT DATE']
        rescue StandardError
          []
        end

        if nex != []
          date = nex.to_date
          nex = []
          nex << date.strftime('%d/')
          nex << date.strftime('%b/')
          nex << date.strftime('%Y')
        end

        (0..(nex.length)).each do |m|
          label.draw_text(nex[m].to_s, 610, (200 + (18 * m)), 0, 2, 1, 1, false)
        end

        user = begin
          "#{encounters[element]['USER'].given_name[0].upcase}.#{encounters[element]['USER'].family_name[0].upcase}"
        rescue StandardError
          ''
        end

        use = user # (encounters[element]["USER"].split(" ") rescue []).collect{|n| n[0,1].upcase + "."}.join("")  rescue ""

        # use = paragraphate(use.to_s, 5, 5)

        # (0..(use.length)).each{|m|
        #   label.draw_text(use[m],710,(200 + (18 * m)),0,2,1,1,false)
        # }

        label.draw_text(use.to_s, 730, 200, 0, 2, 1, 1, false)
      end

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

    def truncate(string, length = 6)
      "#{string[0, length]}."
    end

    def detailed_obstetric_history_label(_date = Date.today)
      @patient = begin
        patient
      rescue StandardError
        nil
      end

      @obstetrics = {}
      search_set = ['YEAR OF BIRTH', 'PLACE OF BIRTH', 'BIRTHPLACE', 'PREGNANCY', 'GESTATION', 'LABOUR DURATION',
                    'METHOD OF DELIVERY', 'CONDITION AT BIRTH', 'BIRTH WEIGHT', 'ALIVE',
                    'AGE AT DEATH', 'UNITS OF AGE OF CHILD', 'PROCEDURE DONE']
      current_level = 0

      @new_encounter = @patient.encounters.joins([:observations]).where(["encounter_type = ? AND comments regexp 'p'",
                                                                         EncounterType.find_by_name('OBSTETRIC HISTORY')]).last

      if @new_encounter.blank?
        Encounter.where(['encounter_type = ? AND patient_id = ?',
                         EncounterType.find_by_name('OBSTETRIC HISTORY').id, @patient.id]).order(['encounter_datetime ASC']).each do |e|
          e.observations.each do |obs|
            concept = begin
              obs.concept.concept_names.map(& :name).last
            rescue StandardError
              nil
            end
            next if concept.nil?

            next unless search_set.include?(concept.upcase)

            if obs.concept_id == begin
              ConceptName.find_by_name('YEAR OF BIRTH').concept_id
            rescue StandardError
              nil
            end
              current_level += 1

              @obstetrics[current_level] = {}
            end

            next unless @obstetrics[current_level]

            @obstetrics[current_level][concept.upcase] = begin
              obs.answer_string
            rescue StandardError
              nil
            end

            next unless obs.concept_id == begin
              ConceptName.find_by_name('YEAR OF BIRTH').concept_id
            rescue StandardError
              nil
            end && obs.answer_string.to_i.zero?

            @obstetrics[current_level]['YEAR OF BIRTH'] = 'Unknown'
          end
        end
      else

        @data = {}
        @new_encounter.observations.each do |obs|
          next unless (obs.comments || '').match(/p/i)

          p = obs.comments.match(/p\d+/i)[0].match(/\d+/)[0]
          n = obs.comments.match(/b\d+/i)[0].match(/\d+/)[0]
          @data[p] = {} if @data[p].blank?
          @data[p][n] = {} if @data[p][n].blank?
          concept = begin
            obs.concept.concept_names.map(& :name).last
          rescue StandardError
            nil
          end
          @data[p][n][concept.upcase.strip] = obs.answer_string
        end

        current_level = 1
        @data.keys.sort.each do |prg|
          @data[prg].keys.sort.each do |key|
            @obstetrics[current_level] = @data[prg][key]
            current_level += 1
          end
        end
      end

      # grab units of age of child
      unit = begin
        Observation.where(['person_id = ? AND concept_id = ?', @patient.id,
                           ConceptName.find_by_name('UNITS OF AGE OF CHILD').concept_id]).last.answer_string.squish
      rescue StandardError
        nil
      end

      # raise @anc_patient.to_yaml

      @pregnancies = active_range

      @range = []

      @pregnancies = @pregnancies[1]

      @pregnancies.each do |preg|
        @range << preg[0].to_date
      end

      @range = @range.sort

      @range.each do |y|
        current_level += 1
        @obstetrics[current_level] = {}
        @obstetrics[current_level]['YEAR OF BIRTH'] = y.year
        @obstetrics[current_level]['PLACE OF BIRTH'] = '<b>(Here)</b>'
      end

      label = ZebraPrinter::StandardLabel.new
      label2 = ZebraPrinter::StandardLabel.new
      label2set = false
      label3 = ZebraPrinter::StandardLabel.new
      label3set = false

      label.draw_text('Detailed Obstetric History', 28, 29, 0, 1, 1, 2, false)
      label.draw_text('Pr.', 35, 65, 0, 2, 1, 1, false)
      label.draw_text('No.', 35, 85, 0, 2, 1, 1, false)
      label.draw_text('Year', 59, 65, 0, 2, 1, 1, false)
      label.draw_text('Place', 110, 65, 0, 2, 1, 1, false)
      label.draw_text('Gest.', 225, 65, 0, 2, 1, 1, false)
      label.draw_text('months', 223, 85, 0, 2, 1, 1, false)
      # label.draw_text("Labour",305,65,0,2,1,1,false)
      # label.draw_text("durat.",305,85,0,2,1,1,false)
      # label.draw_text("(hrs)",310,105,0,2,1,1,false)
      label.draw_text('Delivery', 310, 65, 0, 2, 1, 1, false)
      label.draw_text('Method', 310, 85, 0, 2, 1, 1, false)
      label.draw_text('Condition', 430, 65, 0, 2, 1, 1, false)
      label.draw_text('at birth', 430, 85, 0, 2, 1, 1, false)
      label.draw_text('Birth', 552, 65, 0, 2, 1, 1, false)
      label.draw_text('weight', 547, 85, 0, 2, 1, 1, false)
      label.draw_text('(kg)', 550, 105, 0, 2, 1, 1, false)
      label.draw_text('Alive.', 643, 65, 0, 2, 1, 1, false)
      label.draw_text('now?', 645, 85, 0, 2, 1, 1, false)
      label.draw_text('Age at', 715, 65, 0, 2, 1, 1, false)
      label.draw_text('death*', 715, 85, 0, 2, 1, 1, false)
      label.draw_text("(#{unit[0..2]}.)", 745, 105, 0, 2, 1, 1, false) if unit

      label.draw_line(20, 60, 800, 2, 0)
      label.draw_line(20, 60, 2, 245, 0)
      label.draw_line(20, 305, 800, 2, 0)
      label.draw_line(805, 60, 2, 245, 0)
      label.draw_line(20, 125, 800, 2, 0)

      label.draw_line(56, 60, 2, 245, 0)
      label.draw_line(105, 60, 2, 245, 0)
      label.draw_line(220, 60, 2, 245, 0)
      label.draw_line(295, 60, 2, 245, 0)
      # label.draw_line(380,60,2,245,0)
      label.draw_line(415, 60, 2, 245, 0)
      label.draw_line(535, 60, 2, 245, 0)
      label.draw_line(643, 60, 2, 245, 0)
      label.draw_line(700, 60, 2, 245, 0)

      (1..(@obstetrics.length + 1)).each do |pos|
        @place = (if @obstetrics[pos]
                    (@obstetrics[pos]['BIRTHPLACE'] || '')
                  else
                    ''
                  end).gsub(/Centre/i,
                            'C.').gsub(/Health/i, 'H.').gsub(/Center/i, 'C.')

        @gest = (if @obstetrics[pos]
                   (@obstetrics[pos]['GESTATION'] || '')
                 else
                   ''
                 end)

        @gest = (@gest.length > 5 ? truncate(@gest, 5) : @gest)

        @delmode = (if @obstetrics[pos]
                      (if @obstetrics[pos]['METHOD OF DELIVERY']
                         @obstetrics[pos]['METHOD OF DELIVERY'].titleize
                       else
                         (@obstetrics[pos]['PROCEDURE DONE'] || '')
                       end)
                    else
                      ''
                    end).gsub(/Spontaneous\sVaginal\sDelivery/i,
                              'S.V.D.').gsub(/Caesarean\sSection/i, 'C-Section').gsub(/Vacuum\sExtraction\sDelivery/i,
                                                                                      'Vac. Extr.').gsub('(MVA)', '').gsub(/Manual\sVacuum\sAspiration/i,
                                                                                                                           'M.V.A.').gsub(/Evacuation/i, 'Evac')

        @labor = (if @obstetrics[pos]
                    (@obstetrics[pos]['LABOUR DURATION'] || '')
                  else
                    ''
                  end)

        @labor = (@labor.length > 5 ? truncate(@labor, 5) : @labor)

        @cond = (if @obstetrics[pos]
                   (@obstetrics[pos]['CONDITION AT BIRTH'] || '')
                 else
                   ''
                 end).titleize

        @birt_weig = (if @obstetrics[pos]
                        (@obstetrics[pos]['BIRTH WEIGHT'] || '')
                      else
                        ''
                      end)
        @birt_weig = if @birt_weig.match(/Small/i)
                       '<2.5 kg'
                     else
                       (@birt_weig.match(/Big/i) ? '>4.5 kg' : @birt_weig)
                     end

        @dea = (if @obstetrics[pos]
                  (if @obstetrics[pos]['AGE AT DEATH']
                     @obstetrics[pos]['AGE AT DEATH'].to_s
                   else
                     ''
                   end)
                else
                  ''
                end).to_s +
               (if @obstetrics[pos]
                  (@obstetrics[pos]['UNITS OF AGE OF CHILD'] || '')
                else
                  ''
                end)

        if pos <= 3

          label.draw_text(pos.to_s, 28, (85 + (60 * pos)), 0, 2, 1, 1, false)

          label.draw_text((if @obstetrics[pos]
                             (if @obstetrics[pos]['YEAR OF BIRTH']
                                if @obstetrics[pos]['YEAR OF BIRTH'].to_i.positive?
                                  @obstetrics[pos]['YEAR OF BIRTH'].to_i
                                else
                                  '????'
                                end
                              else
                                ''
                              end)
                           else
                             ''
                           end), 58, (70 + (60 * pos)), 0, 2, 1, 1, false)

          if @place.length < 9
            label.draw_text(@place, 111, (70 + (60 * pos)), 0, 2, 1, 1, false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each do |p|
              label.draw_text(@place[p].to_s, 111, (70 + (60 * pos) + (18 * p)), 0, 2, 1, 1, false)
            end
          end

          label.draw_text(@gest, 225, (70 + (60 * pos)), 0, 2, 1, 1, false)

          # label.draw_text(@labor,300,(70 + (60 * pos)),0,2,1,1,false)

          label.draw_text(@delmode, 300, (70 + (60 * pos)), 0, 2, 1, 1, false)

          label.draw_text(@cond, 420, (70 + (60 * pos)), 0, 2, 1, 1, false)

          label.draw_text(@birt_weig, 539, (70 + (60 * pos)), 0, 2, 1, 1, false)

          label.draw_text((if @obstetrics[pos]
                             (@obstetrics[pos]['ALIVE'] || '')
                           else
                             ''
                           end), 647, (70 + (60 * pos)), 0, 2, 1, 1, false)

          if @dea.length < 10
            label.draw_text(@dea, 708, (70 + (60 * pos)), 0, 2, 1, 1, false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each do |p|
              label.draw_text(@dea[p], 708, (70 + (60 * pos) + (18 * p)), 0, 2, 1, 1, false)
            end
          end

          label.draw_line(20, ((135 + (45 * pos)) <= 305 ? (125 + (60 * pos)) : 305), 800, 2, 0)

        elsif pos >= 4 && pos <= 8
          if pos == 4
            label2.draw_line(20, 30, 800, 2, 0)
            label2.draw_line(20, 30, 2, 275, 0)
            label2.draw_line(20, 305, 800, 2, 0)
            label2.draw_line(805, 30, 2, 275, 0)

            label2.draw_line(55, 30, 2, 275, 0)
            label2.draw_line(105, 30, 2, 275, 0)
            label2.draw_line(220, 30, 2, 275, 0)
            label2.draw_line(295, 30, 2, 275, 0)
            label2.draw_line(380, 30, 2, 275, 0)
            label2.draw_line(510, 30, 2, 275, 0)
            label2.draw_line(615, 30, 2, 275, 0)
            label2.draw_line(683, 30, 2, 275, 0)
            label2.draw_line(740, 30, 2, 275, 0)
          end
          label2.draw_text(pos, 28, ((55 * (pos - 3))), 0, 2, 1, 1, false)

          label2.draw_text((if @obstetrics[pos]
                              (if @obstetrics[pos]['YEAR OF BIRTH']
                                 if @obstetrics[pos]['YEAR OF BIRTH'].to_i.positive?
                                   @obstetrics[pos]['YEAR OF BIRTH'].to_i
                                 else
                                   '????'
                                 end
                               else
                                 ''
                               end)
                            else
                              ''
                            end), 58, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)

          if @place.length < 8
            label2.draw_text(@place, 111, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each do |p|
              label2.draw_text(@place[p], 111, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label2.draw_text(@gest, 225, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)

          label2.draw_text(@labor, 300, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)

          label2.draw_text(@delmode, 385, (55 * (pos - 3)), 0, 2, 1, 1, false)

          if @cond.length < 6
            label2.draw_text(@cond, 515, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)
          else
            @cond = paragraphate(@cond, 6)

            (0..(@cond.length)).each do |p|
              label2.draw_text(@cond[p], 515, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          if @birt_weig.length < 6
            label2.draw_text(@birt_weig, 620, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)
          else
            @birt_weig = paragraphate(@birt_weig, 4)

            (0..(@birt_weig.length)).each do |p|
              label2.draw_text(@birt_weig[p], 620, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label2.draw_text((if @obstetrics[pos]
                              (@obstetrics[pos]['ALIVE'] || '')
                            else
                              ''
                            end), 687, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)

          if @dea.length < 10
            label2.draw_text(@dea, 745, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each do |p|
              label2.draw_text(@dea[p], 745, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label2.draw_line(20, (((55 * (pos - 3)) + 35) <= 305 ? ((55 * (pos - 3)) + 35) : 305), 800, 2, 0)
          label2set = true
        else
          if pos == 9
            label3.draw_line(20, 30, 800, 2, 0)
            label3.draw_line(20, 30, 2, 275, 0)
            label3.draw_line(20, 305, 800, 2, 0)
            label3.draw_line(805, 30, 2, 275, 0)

            label3.draw_line(55, 30, 2, 275, 0)
            label3.draw_line(105, 30, 2, 275, 0)
            label3.draw_line(220, 30, 2, 275, 0)
            label3.draw_line(295, 30, 2, 275, 0)
            label3.draw_line(380, 30, 2, 275, 0)
            label3.draw_line(510, 30, 2, 275, 0)
            label3.draw_line(615, 30, 2, 275, 0)
            label3.draw_line(683, 30, 2, 275, 0)
            label3.draw_line(740, 30, 2, 275, 0)
          end
          label3.draw_text(pos, 28, ((55 * (pos - 8))), 0, 2, 1, 1, false)

          label3.draw_text((if @obstetrics[pos]
                              (if @obstetrics[pos]['YEAR OF BIRTH']
                                 if @obstetrics[pos]['YEAR OF BIRTH'].to_i.positive?
                                   @obstetrics[pos]['YEAR OF BIRTH'].to_i
                                 else
                                   '????'
                                 end
                               else
                                 ''
                               end)
                            else
                              ''
                            end), 58, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)

          if @place.length < 8
            label3.draw_text(@place, 111, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)
          else
            @place = paragraphate(@place)

            (0..(@place.length)).each do |p|
              label3.draw_text(@place[p], 111, (55 * (pos - 8) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label3.draw_text(@gest, 225, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)

          label3.draw_text(@labor, 300, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)

          if @delmode.length < 11
            label3.draw_text(@delmode, 385, (55 * (pos - 8)), 0, 2, 1, 1, false)
          else
            @delmode = paragraphate(@delmode)

            (0..(@delmode.length)).each do |p|
              label3.draw_text(@delmode[p], 385, (55 * (pos - 8) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          if @cond.length < 6
            label3.draw_text(@cond, 515, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)
          else
            @cond = paragraphate(@cond, 6)

            (0..(@cond.length)).each do |p|
              label3.draw_text(@cond[p], 515, (55 * (pos - 8) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          if @birt_weig.length < 6
            label3.draw_text(@birt_weig, 620, (70 + (60 * pos)), 0, 2, 1, 1, false)
          else
            @birt_weig = paragraphate(@birt_weig, 4)

            (0..(@birt_weig.length)).each do |p|
              label3.draw_text(@birt_weig[p], 620, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label3.draw_text((if @obstetrics[pos]
                              (@obstetrics[pos]['ALIVE'] || '')
                            else
                              ''
                            end), 687, ((55 * (pos - 8)) - 13), 0, 2, 1, 1, false)

          if @dea.length < 6
            label3.draw_text(@dea, 745, ((55 * (pos - 3)) - 13), 0, 2, 1, 1, false)
          else
            @dea = paragraphate(@dea, 4)

            (0..(@dea.length)).each do |p|
              label3.draw_text(@dea[p], 745, (55 * (pos - 3) + (18 * p)) - 17, 0, 2, 1, 1, false)
            end
          end

          label3.draw_line(20, (((55 * (pos - 8)) + 35) <= 305 ? ((55 * (pos - 8)) + 35) : 305), 800, 2, 0)
          label3set = true
        end
      end

      if label3set
        label.print(1) + label2.print(1) + label3.print(1)
      elsif label2set
        label.print(1) + label2.print(1)
      else
        label.print(1)
      end
    end

    private

    def getEquivFundalWeeks(fundal_height)
      fundus_weeks = 0

      if fundal_height <= 12

        fundus_weeks = 13

      elsif fundal_height == 13

        fundus_weeks = 14

      elsif fundal_height == 14

        fundus_weeks = 16

      elsif fundal_height == 15

        fundus_weeks = 17

      elsif fundal_height == 16

        fundus_weeks = 18

      elsif fundal_height == 17

        fundus_weeks = 19

      elsif fundal_height == 18

        fundus_weeks = 20

      elsif fundal_height == 19

        fundus_weeks = 21

      elsif fundal_height == 20

        fundus_weeks = 22

      elsif fundal_height == 21

        fundus_weeks = 24

      elsif fundal_height == 22

        fundus_weeks = 25

      elsif fundal_height == 23

        fundus_weeks = 26

      elsif fundal_height == 24

        fundus_weeks = 27

      elsif fundal_height == 25

        fundus_weeks = 28

      elsif fundal_height == 26

        fundus_weeks = 29

      elsif fundal_height == 27

        fundus_weeks = 30

      elsif fundal_height == 28

        fundus_weeks = 32

      elsif fundal_height == 29

        fundus_weeks = 33

      elsif fundal_height == 30

        fundus_weeks = 34

      elsif fundal_height == 31

        fundus_weeks = 35

      elsif fundal_height == 32

        fundus_weeks = 36

      elsif fundal_height == 33

        fundus_weeks = 37

      elsif fundal_height == 34

        fundus_weeks = 38

      elsif fundal_height == 35

        fundus_weeks = 39

      elsif fundal_height == 36

        fundus_weeks = 40

      elsif fundal_height == 37

        fundus_weeks = 42

      elsif fundal_height > 37

        fundus_weeks = 42

      end
      fundus_weeks
    end

    def getObsValue(obs)
      unless obs.value_coded.blank?
        concept = ConceptName.find_by concept_id: obs.value_coded
        return concept.name
      end

      return obs.value_text unless obs.value_text.blank?

      return obs.value_numeric unless obs.value_numeric.nil?

      return obs.value_datetime.to_date.strftime('%Y-%m-%d') unless obs.value_datetime.blank?

      ''
    end

    def paragraphate(string, collen = 8, rows = 2)
      arr = []

      return arr if string.nil?

      string = string.strip

      (0..rows).each do |p|
        unless (string[p * collen, collen]).nil?
          if p == rows
            arr << ("#{string[p * collen, collen]}.") unless (string[p * collen, collen]).nil?
          elsif string[((p * collen) + collen), 1] != ' ' && !string.strip[((p + 1) * collen), collen].nil? &&
                string[(((p + 1) * collen) + collen), 1] != ' '
            arr << ("#{string[p * collen, collen]}-") unless (string[p * collen, collen]).nil?
          elsif !(string[p * collen, collen]).nil?
            arr << string[p * collen, collen]
          end
        end
      end
      arr
    end
  end
end
