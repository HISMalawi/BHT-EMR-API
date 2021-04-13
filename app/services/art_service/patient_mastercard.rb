module ARTService
  class PatientMastercard
    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def data
      {
        pills_brought: get_pills_brought(patient.patient_id, date),
        adherence: get_adherence(patient.patient_id, date),
        pills_given: get_pills_gave(patient.patient_id, date),
        side_effects: get_side_effects(patient.patient_id, date)
      }
    end

    private

    def get_pills_brought(patient_id, visit_date)
      concpet = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC')
      start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
      end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

      data = Observation.where(["person_id = ? AND concept_id = ? AND obs_datetime BETWEEN ? AND ?",
        patient_id, concpet.concept_id, start_date, end_date])

      pills_brought = []
      (data || []).each do |i|
        drug_order = Order.find(i.order_id).drug_order rescue []
        next if drug_order.blank?
        name = drug_order.drug.name rescue ''
        pills_brought << {
          :name       =>  (drug_order.drug.name rescue nil),
          :short_name =>  (drug_order.drug.concept.shortname rescue nil),
          :quantity   => i.value_numeric
        }
      end

      return pills_brought
    end

    def get_adherence(patient_id, visit_date)
      start_date = visit_date.to_date
      end_date = start_date + 1.day

      adherence_observations = Observation.where(
        person_id: patient_id,
        concept_id: ConceptName.where(name: 'Drug Order Adherence')
                               .select(:concept_id),
        obs_datetime: start_date...end_date
      )

      adherence_observations.map do |observation|
        drug_id = observation.value_drug || DrugOrder.find_by_order_id(observation.order_id)&.drug_inventory_id
        next nil unless drug_id

        drug = Drug.find_by_drug_id(drug_id)
        adherence_value = observation.value_numeric
        adherence_value ||= observation.value_text ? observation.value_text.gsub(/%$/, '').to_f : nil

        {
          name: drug&.name,
          short_name: drug&.concept&.shortname,
          adherence: "#{adherence_value}%"
        }
      end
    end

    def get_regimen(patient_id, visit_date)
      amount_dispensed = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
      start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
      end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

      dispensed = Observation.where(["person_id = ? AND concept_id = ? AND obs_datetime BETWEEN ? AND ?",
        patient_id, amount_dispensed, start_date, end_date]).last

      unless dispensed.blank?
        reg = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_current_regimen(#{patient_id}, DATE('#{visit_date.to_date}')) AS regimen_category;
        SQL

        return reg['regimen_category']
      end

      return nil
    end

    def get_pills_gave(patient_id, visit_date)
      order_type = OrderType.find_by_name('Drug Order').id
      start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
      end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

      orders = Order.where(["patient_id = ? AND order_type_id = ? AND start_date BETWEEN ? AND ?",
          patient_id, order_type, start_date, end_date])

      gave = []
      (orders || []).each do |order|
        drug_order = order.drug_order rescue []
        next if drug_order.blank?
        name = drug_order.drug.name rescue ''
        gave << {
          :name       =>  (drug_order.drug.name rescue nil),
          :short_name =>  (drug_order.drug.concept.shortname rescue nil),
          :quantity   =>  drug_order.quantity
        }
      end

      return gave
    end

    def get_side_effects(patient_id, visit_date)
      drug_induced_concept_id = ConceptName.find_by_name('Drug induced').concept_id
      malawi_art_side_effects_concept_id = ConceptName.find_by_name('Malawi ART side effects').concept_id
      no_side_effects_concept_id = ConceptName.find_by_name('No').concept_id
      yes_side_effects_concept_id = ConceptName.find_by_name('Yes').concept_id

      malawi_side_effects_ids =  ActiveRecord::Base.connection.select_all <<~SQL
          SELECT t1.person_id patient_id, t1.obs_id, value_coded, t1.obs_datetime
          FROM obs t1
          where t1.person_id = #{patient_id}
          AND t1.voided = 0 AND concept_id IN(#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id})
          AND t1.obs_datetime = (SELECT max(obs_datetime) FROM obs t2
          WHERE t2.voided = 0 AND t2.person_id = t1.person_id
          AND t2.concept_id IN(#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id})
          AND t2.obs_datetime BETWEEN '#{visit_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{visit_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          ) GROUP BY t1.person_id, t1.value_coded
        #HAVING DATE(obs_datetime) != DATE(earliest_start_date);
      SQL

      results = []
      (malawi_side_effects_ids || []).each do |row|
        obs_group = Observation.where(["concept_id = ? AND obs_group_id = ?",
            row['value_coded'].to_i, row['obs_id'].to_i]).first rescue nil

        if obs_group.blank?
            next if no_side_effects_concept_id == row['value_coded'].to_i
            results << ConceptName.find_by_concept_id(row['value_coded']).name
        elsif obs_group.value_coded == yes_side_effects_concept_id
            results << ConceptName.find_by_concept_id(obs_group.concept_id).name
        end
      end

      return results
    end
  end
end
