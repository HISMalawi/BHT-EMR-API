# frozen_string_literal: true

# Investigation Service
module RadiologyService
  # Investigation Class
  class Investigation
    def initialize(patient_id:, date:)
      @patient = Patient.find(patient_id)
      @date = date
    end

    def examinations
      order_type = OrderType.find_by_name('Radiology')
      @patient.orders.where('order_type_id = ? AND start_date BETWEEN ? AND ?', order_type,
                            @date.to_date.strftime('%Y-%m-%d 00:00:00'), @date.to_date.strftime('%Y-%m-%d 23:59:59'))
    end

    def all_examinations
      order_type = OrderType.find_by_name('Radiology')
      results = @patient.orders.where('order_type_id = ?', order_type).order('start_date DESC')

      results.map do |order|
        label = RadiologyService::OrderLabel.new(order_id: order.id)
        { examination_name: examination_output(label),
          order_date: order.start_date, accession_number: order.accession_number, patient_id: order.patient_id }
      end
    end

    def examination_output(label)
      examination_name = ''
      examination_name += label.order_type
      examination_name += "-#{label.examination}" unless label.examination.blank?
      examination_name += "-#{label.detailed_examination}" unless label.detailed_examination.blank?
      examination_name
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def self.create_order(params)
      order_type = OrderType.find_by_name('Radiology')
      encounter = Encounter.find(params[:encounter_id])
      Order.create!(order_type:,
                    concept_id: params[:concept_id] || unknown_concept_id,
                    encounter_id: encounter.id,
                    instructions: params[:instructions],
                    start_date: params[:start_date] || encounter.encounter_datetime,
                    orderer: params[:orderer] || User.current.id,
                    accession_number: params[:accession_number] || AccessionNumberService.next_accession_number,
                    provider: params[:provider] || User.current,
                    patient_id: encounter.patient_id)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def self.radiology_concept_set(key)
      case sanitaniaze_params(key).class.to_s
      when 'String'
        values = ConceptSet.find_members_by_name(key)
      when 'Integer'
        values = ConceptSet.where(concept_set: key)
      end

      result = values.map do |concept_set|
        { concept_id: concept_set.concept_id, name: concept_set.concept.fullname || concept_set.concept.shortname }
      end

      result.sort_by! { |concept_set| concept_set[:name] }
    end

    def self.sanitaniaze_params(params)
      Integer(params)
    rescue StandardError
      params
    end

    def unknown_concept_id
      ConceptName.find_by_name!('Unknown').concept_id
    end
  end
end
