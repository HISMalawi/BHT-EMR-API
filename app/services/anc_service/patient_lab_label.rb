# frozen_string_literal: true

module AncService
  class PatientLabLabel
    attr_accessor :patient, :date

    LAB_RESULTS = EncounterType.find_by name: "LAB RESULTS"
    ANC_PROGRAM = Program.find_by name: "ANC PROGRAM"

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def patient_labs
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT CONCAT(obs.value_modifier, COALESCE(obs.value_numeric, ''), COALESCE(obs.value_text, '')) result,
              DATE(obs.obs_datetime) test_date,
              tn.name test
        FROM `obs`
          INNER JOIN `encounter` ON `encounter`.`voided` = 0 AND `encounter`.`encounter_id` = `obs`.`encounter_id`
          INNER JOIN obs tt on tt.order_id = obs.order_id
          INNER join concept_name tn on tn.concept_id = tt.value_coded
        WHERE `obs`.`voided` = 0
          AND (encounter.program_id = #{ANC_PROGRAM.id})
          AND (encounter_type = #{EncounterType.find_by_name("LAB ORDERS").id})
          AND (obs.concept_id in (SELECT concept_set.concept_id
                                  FROM concept_set
                                  WHERE concept_set in
                                        (
                                          SELECT concept_id 
                                          FROM concept_name 
                                          WHERE name = 'Lab test result indicator')
                                        ))
          AND (tt.concept_id = (SELECT concept_id
                                FROM concept_name
                                WHERE name = 'Test type'))

          AND (obs.person_id = #{patient.id})
        GROUP BY tt.value_coded
      SQL
    end

    def print
      syphil = {}
      @patient.encounters.where(["encounter_type IN (?) AND program_id = ?",
                                 LAB_RESULTS.id, ANC_PROGRAM.id]).each do |e|
        e.observations.each do |o|
          concept_name = o.concept.concept_names.map(&:name).last.upcase
          syphil[concept_name] = o.answer_string.squish.upcase
          syphil["encounter_date"] = e.encounter_datetime.to_date.strftime("%Y-%m-%d")

          if ["PREVIOUS HIV TEST RESULTS", "HIV STATUS"].include?(concept_name)
            syphil["HIV TEST DATE"] =
              e.encounter_datetime.to_date.strftime("%Y-%m-%d")
          end
        end
      end
      @encounter_datetime = syphil["encounter_date"]

      @syphilis = begin
          syphil["SYPHILIS TEST RESULT"].titleize
        rescue StandardError
          ""
        end

      @syphilis_date = begin
          syphil["SYPHILIS TEST RESULT"].match(/not done/i) ? "" : syphil["SYPHILIS TEST RESULT DATE"]
        rescue StandardError
          nil
        end

      @malaria = begin
          syphil["MALARIA TEST RESULT"].titleize
        rescue StandardError
          ""
        end

      @blood_group = begin
          syphil["BLOOD GROUP"]
        rescue StandardError
          ""
        end

      @malaria_date = begin
          syphil["MALARIA TEST RESULT"].match(/not done/i) ? "" : syphil["DATE OF LABORATORY TEST"]
        rescue StandardError
          nil
        end

      hiv_test = syphil["HIV STATUS"].blank? ? syphil["PREVIOUS HIV TEST RESULTS"] : syphil["HIV STATUS"]

      @hiv_test = begin
          (if hiv_test.downcase == "positive"
            "="
          else
            (hiv_test.downcase == "negative" ? "-" : "")
          end)
        rescue StandardError
          ""
        end

      # @hiv_test_date = syphil["HIV STATUS"].match(/not done/i) ? "" : syphil["HIV TEST DATE"] rescue nil

      hiv_test_date = begin
          syphil["HIV TEST DATE"].blank? ? syphil["PREVIOUS HIV TEST DATE"] : syphil["HIV TEST DATE"]
        rescue StandardError
          nil
        end

      @hiv_test_date = begin
          hiv_test_date.to_date.strftime("%Y-%m-%d")
        rescue StandardError
          ""
        end

      @hepatitis_b = "#{syphil["HEPATITIS B TEST RESULT"]&.humanize}"

      @hb = "#{syphil["HB TEST RESULT"]&.humanize}"

      @serum_glucose = "#{syphil["BLOOD GLUCOSE"]}"

      @hb2_date = @encounter_datetime

      @cd4 = begin
          syphil["CD4 COUNT"]
        rescue StandardError
          nil
        end

      @cd4_date = begin
          syphil["CD4 COUNT DATETIME"]
        rescue StandardError
          nil
        end

      @height = current_height.to_f # rescue nil

      @weight = current_weight.to_f

      @multiple = begin
          Observation.where(["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
                             @patient.id, Encounter.where(["encounter_type = ?",
                                                           EncounterType.find_by_name("CURRENT PREGNANCY").id]).collect(&:encounter_id),
                             ConceptName.find_by_name("Multiple Gestation").concept_id]).last.answer_string.squish
        rescue StandardError
          nil
        end

      @who = begin
          Encounter.find_by_sql("SELECT who_stage(#{@patient.id}, #{if session[:datetime]
            session[:datetime].to_date
          else
            Date.today
          end})")
        rescue StandardError
          nil
        end

      extra_labs = [[
        {
          "test": 'HIV',
          "test_date": @hiv_test_date,
          "result": @hiv_test
        },
        {
          "test": 'Syphilis',
          "test_date":  @date.to_date.strftime("%Y-%m-%d"),
          "result": @syphilis
        },
        {
          "test": 'Hb',
          "test_date": @hb2_date,
          "result": @hb
        },
        {
          "test": 'Malaria',
          "test_date":  @date.to_date.strftime("%Y-%m-%d"),
          "result": @malaria
        },
        {
          "test": 'Blood Group',
          "test_date": @encounter_datetime,
          "result": @blood_group
        },
        {
          "test": 'Hepatitis B',
          "test_date": @encounter_datetime,
          "result": @hepatitis_b
        },
        {
          "test": 'BG',
          "test_date": @encounter_datetime,
          "result": @serum_glucose
        }
      ], patient_labs&.to_a].flatten!&.map(&:symbolize_keys)

      extra_labs = extra_labs.filter! { |lab| !lab[:result].blank? && !lab[:test_date].blank? }

      label = ZebraPrinter::Lib::StandardLabel.new

      label.draw_text("Examination", 28, 9, 0, 1, 1, 2, false)
      label.draw_line(25, 35, 115, 1, 0)
      label.draw_line(180, 140, 250, 1, 0)

      label.draw_text("Height", 28, 56, 0, 2, 1, 1, false)
      label.draw_text("Weight", 28, 86, 0, 2, 1, 1, false)

      label.draw_text("Lab Tests", 28, 111, 0, 1, 1, 2, false)
      label.draw_text("Date", 190, 120, 0, 2, 1, 1, false)
      label.draw_text("Result", 325, 120, 0, 2, 1, 1, false)


      # label.draw_text("HIV", 28, 146, 0, 2, 1, 1, false) if @hiv_test.present?
      # label.draw_text("Syphilis", 28, 176, 0, 2, 1, 1, false) if @syphilis.present?
      # label.draw_text("Hb", 28, 206, 0, 2, 1, 1, false) if @hb.present?
      # # label.draw_text("Hb2",28,256,0,2,1,1,false)
      # label.draw_text("Malaria", 28, 236, 0, 2, 1, 1, false) if @malaria.present?
      # label.draw_text("Blood Group", 28, 266, 0, 2, 1, 1, false) if @blood_group.present?
      row_limit = 4


      index = 146
      extra_labs.take(row_limit).each do |lab|
        next if lab[:result].blank?

        label.draw_text(lab[:test], 28, index, 0, 2, 1, 1, false)
        index += 30
      end


      label.draw_line(260, 50, 170, 1, 0)
      label.draw_line(260, 50, 1, 60, 0)
      label.draw_line(180, 286, 250, 1, 0)
      label.draw_line(430, 50, 1, 60, 0)

      label.draw_line(180, 140, 1, 145, 0)
      label.draw_line(320, 140, 1, 145, 0)
      label.draw_line(430, 140, 1, 145, 0)

      label.draw_line(260, 80, 170, 1, 0)
      label.draw_line(260, 110, 170, 1, 0)
      label.draw_line(260, 140, 170, 1, 0)

      label.draw_line(180, 170, 250, 1, 0)
      label.draw_line(180, 200, 250, 1, 0)
      label.draw_line(180, 230, 250, 1, 0)
      label.draw_line(180, 260, 250, 1, 0)


      if extra_labs.length > 0
        label.draw_line(550, 80, 250, 1, 0)

        
        extra_labs.length.times do |i|
          label.draw_line(560, 80 + (i+1) * 30, 250, 1, 0)
        end
      end
      
      extra_labs.drop(row_limit).each_with_index do |lab, i|
        
        next if lab[:result].blank?

        label.draw_text(lab[:test_date], 435, 56+((i+1) * 30), 0, 2, 1, 1, false)
        label.draw_text(lab[:test], 560, 56+((i+1) * 30), 0, 2, 1, 1, false)
        label.draw_text(lab[:result], 710, 56+((i+1) * 30), 0, 2, 1, 1, false)
      end

      label.draw_line(560, 80, 1, extra_labs.length * 30, 0)
      label.draw_line(700, 80, 1, extra_labs.length * 30, 0)
      
      label.draw_text(@height.blank? ? "N/A" : "#{@height} CM", 270, 56, 0, 2, 1, 1, false)
      label.draw_text(@weight.blank? ? "N/A" : "#{@weight} KG", 270, 86, 0, 2, 1, 1, false)
      # label.draw_text(@who,270,136,0,2,1,1,false)
      @date = (if @encounter_datetime.blank?
        begin
          @date.to_date.strftime("%Y-%m-%d")
        rescue StandardError
          ""
        end
      else
        @encounter_datetime
      end)

      # label.draw_text((@hiv_test_date.blank? ? @encounter_datetime : @hiv_test_date.to_s), 188, 146, 0, 2, 1, 1, false) if @hiv_test.present?
      # label.draw_text((@syphilis.blank? ? "N/A" : @date.to_s).to_s, 188, 176, 0, 2, 1, 1, false) if @syphilis.present?
      # label.draw_text((@hb.blank? ? "N/A" : @date.to_s).to_s, 188, 206, 0, 2, 1, 1, false) if @hb.present?
      # label.draw_text((@malaria.blank? ? "N/A" : @date.to_s).to_s, 188, 236, 0, 2, 1, 1, false) if @malaria.present?
      # label.draw_text((@blood_group.blank? ? "N/A" : @date.to_s).to_s, 188, 266, 0, 2, 1, 1, false) if @blood_group.present?

      # label.draw_text(@hiv_test.to_s, 345, 146, 0, 2, 1, 1, false) if @hiv_test.present?
      # label.draw_text((@syphilis.blank? ? "N/A" : @syphilis.to_s).to_s, 325, 176, 0, 2, 1, 1, false) if @syphilis.present?
      # label.draw_text((@hb.blank? ? @hb2 ||= "N/A" : @hb.to_s).to_s, 325, 206, 0, 2, 1, 1, false) if @hb.present?
      # # label.draw_text(@hb2,325,256,0,2,1,1,false)
      # label.draw_text((@malaria.blank? ? "N/A" : @malaria.to_s).to_s, 325, 236, 0, 2, 1, 1, false) if @malaria.present?
      # label.draw_text((@blood_group.blank? ? "N/A" : @blood_group.to_s).to_s, 325, 266, 0, 2, 1, 1, false) if @blood_group.present?
      
      index = 146
      extra_labs.take(row_limit).each do |lab|
        next if lab[:result].blank?

        label.draw_text(lab[:test_date], 188, index, 0, 2, 1, 1, false)
        index += 30
      end

      index = 146
      extra_labs.take(row_limit).each do |lab|
        next if lab[:result].blank?

        label.draw_text(lab[:result], 325, index, 0, 2, 1, 1, false)
        index += 30
      end

      # label.draw_text(@malaria,188,226,0,2,1,1,false)

      {
        data: {
          height: @height,
          weight: @weight,
          date: @date,
          hiv_test: @hiv_test,
          hiv_test_date: @hiv_test_date,
          syphilis: @syphilis,
          syphilis_date: @syphilis_date,
          hb: @hb,
          hb_date: @hb2_date,
          malaria: @malaria,
          malaria_date: @malaria_date,
          blood_group: @blood_group,
        },
        zpl: label.print(1),
      }
    end

    def get_identifier(type = "National id")
      identifier_type = PatientIdentifierType.find_by_name(type)
      return if identifier_type.blank?

      identifiers = patient.patient_identifiers.find_all_by_identifier_type(identifier_type.id)
      return if identifiers.blank?

      begin
        identifiers.map(&:identifier).join(" , ")
      rescue StandardError
        nil
      end
    end

    def current_weight
      weight = ConceptName.find_by name: "Weight"
      @current_weight ||= begin
          Observation.where(concept_id: weight.concept_id, person_id: @patient.person.id)
                     .where("obs_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(date))
                     .last
                     .value_numeric
        rescue StandardError
          0
        end
    end

    def current_height
      height = ConceptName.find_by name: "Height (cm)"
      @current_height ||= begin
          Observation.where(concept_id: height.concept_id, person_id: @patient.person.id)
                     .order(obs_datetime: :desc)
                     .first.value_numeric
        rescue StandardError
          0
        end
    end
  end
end
