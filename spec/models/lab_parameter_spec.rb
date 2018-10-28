# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LabParameter do
  describe 'Field validations' do
    it 'requires Range to be one of <, >, or =' do
      parameter = LabParameter.create Sample_ID: 1,
                                      TESTTYPE: 1,
                                      TESTVALUE: 10,
                                      Range: '!='

      expect(parameter.errors[:Range].size).to eq 1
      expect(parameter.errors[:Range][0]).to eq 'Range must be one of <, >, or ='
    end

    it 'saves if validations are successful' do
      parameter = LabParameter.create Sample_ID: 1,
                                      TESTTYPE: 1,
                                      TESTVALUE: 10,
                                      Range: '='

      expect(parameter.errors[:Range].empty?).to be true
    end
  end
end
