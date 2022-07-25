# frozen_string_literal: true

# Investigation Service
module RadiologyService
  # Investigation Class
  class Investigation
    def initialize(patient_id, date)
      @pateint = Patient.find(patient_id)
      @date = date
    end

    def examinations
      order_type = OrderType.find_by_name('Radiology')
      @patient.orders.where('order_type = ? AND start_date BETWEEN ? AND ?', order_type,
                            @date.to_date.strftime('%Y-%m-%d 00:00:00'), @date.to_date.strftime('%Y-%m-%d 23:59:59'))
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def create_order(params)
      order_type = OrderType.find_by_name('Radiology')
      encounter = Encounter.find(params[:encounter_id])
      Order.create!(order_type: order_type,
                    concept_id: params[:concept_id] || unknown_concept_id,
                    encounter_id: encounter.id,
                    instructions: params[:instructions],
                    start_date: params[:start_date] || Time.now,
                    auto_expire_date: params[:auto_expire_date],
                    orderer: params[:orderer] || User.current.id,
                    accession_number: params[:accession_number] || AccessionNumberService.next_accession_number,
                    provider: params[:provider] || User.current.id,
                    patient_id: @patient.id)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def self.radiology_concept_set(key)
      case key.class.to_s
      when 'String'
        values = ConceptSet.find_members_by_name(key)
      when 'Integer'
        values = ConceptSet.where(concept_set: key)
      end

      values.map do |concept_set|
        { id: concept_set.concept_id, name: concept_set.concept.fullname }
      end
    end

    def unknown_concept_id
      ConceptName.find_by_name!('Unknown').concept_id
    end
  end
end
