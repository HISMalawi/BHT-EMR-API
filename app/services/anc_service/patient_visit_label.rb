# frozen_string_literal: true

module ANCService
  class PatientVisitLabel
    attr_accessor :patient, :date

    PROGRAM = Program.find_by name: 'ANC PROGRAM'

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def print
      print1 + print2
    end

    def print1
      visit = ANCService::PatientVisit.new patient, date
      return unless visit

      @current_range = visit.active_range(@date.to_date)

      encounters = {}

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        encounters[e.encounter_datetime.strftime('%d/%b/%Y')] = { 'USER' => PersonName.find_by(person_id: e.creator) }
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
              encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] += '; ' + value
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
              (o.drug_order.drug.name[0, o.drug_order.drug.name.index(' ')].to_s + ' ' +
                              o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0])
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
      label.draw_text('Visit Summary', 28, 33, 0, 1, 1, 2, false)
      label.draw_text("Last Menstrual Period: #{begin
        @current_range[0]['START'].to_date.strftime('%d/%b/%Y')
      rescue StandardError
        ''
      end}",
                      28, 76, 0, 2, 1, 1, false)
      label.draw_text(
        "Expected Date of Delivery: #{begin
          (@current_range[0]['END'].to_date - 5.week).strftime('%d/%b/%Y')
        rescue StandardError
          ''
        end}", 28, 99, 0, 2, 1, 1, false
      )
      label.draw_line(28, 60, 132, 1, 0)
      label.draw_line(20, 130, 800, 2, 0)
      label.draw_line(20, 190, 800, 2, 0)
      label.draw_text('Gest.', 29, 140, 0, 2, 1, 1, false)
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
      label.draw_text('Age', 35, 158, 0, 2, 1, 1, false)
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
        encounter = encounters[element]

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

        gest = begin
          gestation_weeks.to_s + 'wks'
        rescue StandardError
          ''
        end

        label.draw_text(gest, 29, 200, 0, 2, 1, 1, false)

        fund = begin
          (fundal_height <= 0 ? '?' : fundal_height.to_s + '(cm)')
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

        bp = paragraphate(sbp.to_s + '/' + dbp.to_s, 4, 3)

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
          (@drugs[element]['SP'].to_i > 0 ? @drugs[element]['SP'].to_i : '')
        rescue StandardError
          ''
        end

        label.draw_text(sp, 595, 200, 0, 2, 1, 1, false)

        @ferrous_fefol = begin
          @other_drugs.keys.collect do |date|
            @other_drugs[date].keys.collect do |key|
              @other_drugs[date][key] if begin
                (@other_drugs[date][key].to_i > 0 and key.downcase.strip == 'ferrous')
              rescue StandardError
                false
              end
            end
          end.compact.first.to_s
        rescue StandardError
          ''
        end

        fefo = begin
          (@drugs[element]['Fefol'].to_i > 0 ? @drugs[element]['Fefol'].to_i : '')
        rescue StandardError
          ''
        end

        fefo = begin
          (fefo.to_i + @ferrous_fefol.to_i)
        rescue StandardError
          fefo
        end
        fefo = '' if begin
          fefo.to_i == 0
        rescue StandardError
          false
        end

        label.draw_text(fefo.to_s, 664, 200, 0, 2, 1, 1, false)

        albe = begin
          (@drugs[element]['Albendazole'].to_i > 0 ? @drugs[element]['Albendazole'].to_i : '')
        rescue StandardError
          ''
        end

        label.draw_text(albe.to_s, 740, 200, 0, 2, 1, 1, false)
      end

      @encounters = encounters

      label.print(1)
    end

    def print2
      visit = ANCService::PatientVisit.new patient, date
      return unless visit

      @current_range = visit.active_range(@date.to_date)

      # raise @current_range.to_yaml

      encounters = {}

      @patient.encounters.where(['encounter_datetime >= ? AND encounter_datetime <= ? AND program_id = ?',
                                 @current_range[0]['START'], @current_range[0]['END'], PROGRAM.id]).collect do |e|
        encounters[e.encounter_datetime.strftime('%d/%b/%Y')] =
          { 'USER' => PersonName.find_by(person_id: e.creator) }
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
              encounters[e.encounter_datetime.strftime('%d/%b/%Y')][e.type.name.upcase][concept.name.upcase] += '; ' + value
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
              (o.drug_order.drug.name[0, o.drug_order.drug.name.index(' ')] + ' ' +
                              o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0])
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
      end}", 28, 66, 0, 2,
                      1, 1, false)
      label.draw_text("Bed Net Given: #{begin
        @current_range[0]['MOSQUITO NET']
      rescue StandardError
        ''
      end}", 28, 99, 0, 2, 1, 1, false)
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
          (@drugs[element]['TD'] > 0 ? 1 : '')
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
          encounters[element]['UPDATE OUTCOME']['OUTCOME'].humanize + '; '
        rescue StandardError
          ''
        end
        begin
          if @other_drugs[element].length > 0
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
          "#{encounters[element]['USER'].given_name[0]} . #{encounters[element]['USER'].family_name[0]}"
        rescue StandardError
          ''
        end

        use = user # (encounters[element]["USER"].split(" ") rescue []).collect{|n| n[0,1].upcase + "."}.join("")  rescue ""

        # use = paragraphate(use.to_s, 5, 5)

        # (0..(use.length)).each{|m|
        #   label.draw_text(use[m],710,(200 + (18 * m)),0,2,1,1,false)
        # }

        label.draw_text(use.to_s, 710, 200, 0, 2, 1, 1, false)
      end

      label.print(1)
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
            arr << (string[p * collen, collen] + '.') unless (string[p * collen, collen]).nil?
          elsif string[((p * collen) + collen), 1] != ' ' && !string.strip[((p + 1) * collen), collen].nil? &&
                string[(((p + 1) * collen) + collen), 1] != ' '
            arr << (string[p * collen, collen] + '-') unless (string[p * collen, collen]).nil?
          elsif !(string[p * collen, collen]).nil?
            arr << string[p * collen, collen]
          end
        end
      end
      arr
    end
  end
end
