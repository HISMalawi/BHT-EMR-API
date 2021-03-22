# frozen_string_literal: true

require 'logger'
require 'rails_helper'

RdsService::LOGGER.level = Logger::INFO

RSpec.describe RdsService do
  let(:rds_service) do
    rds_service = Object.new
    rds_service.extend(RdsService)
    rds_service
  end

  let(:health_center_id) do
    GlobalProperty.where(property: 'current_health_center_id').each(&:destroy)
    property = create :global_property, property: 'current_health_center_id',
                                        property_value: 20
    property.property_value
  end

  describe :transform_record_keys do
    it 'updates all foreign keys pointing to rds target records' do
      encounter = create :encounter
      program = encounter.program

      program_id = program.id.to_s.rjust(RdsService::PROGRAM_ID_MAX_WIDTH, '0')
      site_id = health_center_id.to_s.rjust(RdsService::SITE_CODE_MAX_WIDTH, '0')

      record = rds_service.transform_record_keys(encounter, encounter.as_json(ignore_includes: true), program)
      expect(record['patient_id']).not_to eq(encounter.patient)
      expect(record['encounter_id'].to_s).to match(/#{encounter.id}#{program_id}#{site_id}$/)
    end
  end
end
