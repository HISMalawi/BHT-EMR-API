# frozen_string_literal: true

module ARTService
  # Prints out patient transfer out labels
  #
  # Source: NART/app/controllers/generic_patients_controller#patient_transfer_out_label
  class PatientTransferOutLabel
    attr_reader :patient, :date, :transfer_out_note

    def initialize(patient, date)
      @patient = patient
      @date = date
      @transfer_out_note = ARTService::PatientTransferOut.new patient, date
    end

    def print
      who_stage = transfer_out_note.reason_for_art_eligibility
      initial_staging_conditions = transfer_out_note.who_clinical_conditions
      destination = transfer_out_note.transferred_out_to

      label = ZebraPrinter::Label.new(776, 329, 'T')
      label.line_spacing = 0
      label.top_margin = 30
      label.bottom_margin = 30
      label.left_margin = 25
      label.x = 25
      label.y = 30
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1

      # 25, 30
      # Patient personanl data
      label.draw_multi_text("#{Location.current_health_center.name} transfer out label", font_reverse: true)
      label.draw_multi_text("To #{destination}", font_reverse: false) unless destination.blank?
      label.draw_multi_text("ARV number: #{patient.identifier('ARV Number')&.identifier}", font_reverse: true)
      label.draw_multi_text("Name: #{patient.name} (#{patient.gender.first})\nAge: #{patient.age}", font_reverse: false)

      # Print information on Diagnosis!
      art_start_date = transfer_out_note.date_antiretrovirals_started&.strftime('%d-%b-%Y')
      label.draw_multi_text('Stage defining conditions:', font_reverse: true)
      label.draw_multi_text("Reason for starting: #{who_stage}", font_reverse: false)
      label.draw_multi_text("ART start date: #{art_start_date}", font_reverse: false)
      label.draw_multi_text('Other diagnosis:', font_reverse: true)
      # !!!! TODO
      staging_conditions = ''
      count = 1
      initial_staging_conditions.each do |condition|
        if staging_conditions.blank?
          staging_conditions = "(#{count}) #{condition}" unless condition.blank?
        else
          staging_conditions += " (#{count += 1}) #{condition}" unless condition.blank?
        end
      end
      label.draw_multi_text(staging_conditions.to_s, font_reverse: false)

      # Print information on current status of the patient transfering out!
      initial_height = "Init HT: #{transfer_out_note.initial_height}"
      initial_weight = "Init WT: #{transfer_out_note.initial_weight}"

      first_cd4_count = 'CD count ' + transfer_out_note.cd4_count if transfer_out_note.cd4_count
      unless transfer_out_note.cd4_count_date.blank?
        first_cd4_count_date = "CD count date #{transfer_out_note.cd4_count_date.strftime('%d-%b-%Y')}"
      end
      # renamed current status to Initial height/weight as per minimum requirements
      label.draw_multi_text('Initial Height/Weight', font_reverse: true)
      label.draw_multi_text("#{initial_height} #{initial_weight}", font_reverse: false)
      label.draw_multi_text(first_cd4_count.to_s, font_reverse: false)
      label.draw_multi_text(first_cd4_count_date.to_s, font_reverse: false)

      # irint information on current treatment of the patient transfering out!

      concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
      previous_orders = Order.joins("INNER JOIN obs ON obs.order_id = orders.order_id LEFT JOIN drug_order ON
        orders.order_id = drug_order.order_id").where(["obs.person_id = ? AND obs.concept_id = ?
            AND obs_datetime <=?", patient.id, concept_id, date.strftime('%Y-%m-%d 23:59:59')]).order('obs_datetime DESC').select('obs.obs_datetime, drug_order.drug_inventory_id')

      previous_date = nil
      drugs = []

      finished = false

      reg = []

      previous_orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
        next unless drug.arv?
        next if finished

        previous_date = order.obs_datetime.to_date if previous_date.blank?
        if previous_date == order.obs_datetime.to_date
          reg << (drug.concept.shortname || drug.concept.fullname)
          previous_date = order.obs_datetime.to_date
        else
          finished = true unless drugs.blank?
        end
      end

      reg = reg.uniq.join(' + ')

      label.draw_multi_text('Current ART drugs', font_reverse: true)
      label.draw_multi_text(reg, font_reverse: false)
      label.draw_multi_text('Transfer out date:', font_reverse: true)
      label.draw_multi_text(date.strftime('%d-%b-%Y').to_s, font_reverse: false)

      label.print(1)
    end
  end
end
