# frozen_string_literal: true

require 'swagger_helper'

TAG = 'Patients'
TAG_DESCRIPTION = 'Patient related endpoints'

RSpec.describe 'api/v1/patients', type: :request do
  path '/api/v1/patients/{patient_id}/labels/national_health_id' do
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('print_national_health_id_label patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/labels/filing_number' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('print_filing_number patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/labels/print_tb_number' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('print_tb_number patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/labels/print_tb_lab_order_summary' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('print_tb_lab_order_summary patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/visits' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('visits patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/visit' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('visit patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/tpt_status' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('tpt_status patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/drugs_received' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('drugs_received patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/last_drugs_received' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('last_drugs_received patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/drugs_orders_by_program' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('drugs_orders_by_program patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/recent_lab_orders' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('recent_lab_orders patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/current_bp_drugs' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('current_bp_drugs patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/last_bp_drugs_dispensation' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('last_bp_drugs patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/median_weight_height' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('find_median_weight_and_height patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/bp_trail' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('bp_readings_trail patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/eligible_for_htn_screening' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('eligible_for_htn_screening patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/filing_number' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    post('assign_filing_number patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/past_filing_numbers' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('filing_number_history patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/assign_tb_number' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    get('assign_tb_number patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/npid' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    post('assign_npid patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/remaining_bp_drugs' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    post('remaining_bp_drugs patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{patient_id}/update_or_create_htn_state' do
    # You'll want to customize the parameter types...
    parameter name: 'patient_id', in: :path, type: :string, description: 'patient_id'

    post('update_or_create_htn_state patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:patient_id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients' do

    get('list patients') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end

    post('create patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/patients/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      response(200, 'successful') do
        let(:id) { '123' }
        schema '$ref' => '#/components/schemas/patient'
        run_test!
      end
    end

    put('update patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end

    delete('delete patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        let(:id) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/search/patients/by_npid' do

    get('search_by_npid patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/search/patients/by_identifier' do

    get('search_by_identifier patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/search/patients' do

    get('search_by_name_and_gender patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/archiving_candidates' do

    get('find_archiving_candidates patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/last_drugs_pill_count' do

    get('last_drugs_pill_count patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/tpt_prescription_count' do

    get('tpt_prescription_count patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/last_cxca_screening_details' do

    get('last_cxca_screening_details patient') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end
