# frozen_string_literal: true

require 'swagger_helper'

TAGS_NAME = 'Clinic Reports'

# rubocop:disable Metrics/BlockLength
describe 'Clinic Reports API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/programs/1/reports/clinic_tx_rtt' do
    get 'Retrieve CLINIC TX RTT report' do
      tags TAGS_NAME
      description 'This shows CLINIC TX RTT report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'CLINIC TX RTT Report found' do
        schema type: :object, properties: {
          age_group: { type: :object, properties: {
            gender: { type: :array, items: {
              type: :object, properties: {
                patient_id: { type: :integer },
                months: { type: :integer }
              }
            } }
          } }
        }
        run_test!
      end

      response '404', 'CLINIC TX RTT Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/tpt_outcome' do
    get 'Retrieve TPT OUTCOME report' do
      tags TAGS_NAME
      description 'This shows TPT OUTCOME report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'TPT OUTCOME Report found' do
        schema type: :array, items: {
          type: :object, properties: {
            age_group: { type: :string },
            tpt_type: { type: :string },
            started_tpt: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            completed_tpt: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            not_completed_tpt: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            died: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            defaulted: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            transferred_out: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            confirmed_tb: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            pregnant: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            stopped: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            breast_feeding: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            skin_rash: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            peripheral_neuropathy: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            yellow_eyes: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            nausea: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } },
            dizziness: { type: :array, items: {
              type: :object,
              properties: {
                patient_id: { type: :integer },
                gender: { type: :string }
              }
            } }
          }
        }
        run_test!
      end

      response '404', 'TPT OUTCOME Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path 'api/v1/programs/1/reports/lims_electronic_results' do
    get 'Retrieve LIMS ELECTRONIC RESULTS report' do
      tags TAGS_NAME
      description 'This shows LIMS ELECTRONIC RESULTS report'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'LIMS ELECTRONIC RESULTS Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/lims_electronic_result' }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/vl_collection' do
    get 'Retrieve VL Collection report' do
      tags TAGS_NAME
      description 'This shows Viral Load Collection report'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'VL Collection Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/vl_collection' }
        run_test!
      end

      response '404', 'VL Collection Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/discrepancy_report' do
    get 'Retrieve Discrepancy report' do
      tags TAGS_NAME
      description 'This shows Discrepancy report'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'Discrepancy Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/discrepancy_report' }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/hypertension_report' do
    get 'Retrieve Hypertension report' do
      tags TAGS_NAME
      description 'This shows Hypertension report'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'Hypertension Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/hypertension_report' }
        run_test!
      end
    end
  end

  path '/api/v1/dashboard_stats' do
    get 'Retrieve CLINIC Dashboard report' do
      tags TAGS_NAME
      description 'This shows CLINIC TDashboard report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :date, in: :query, type: :string
      parameter name: :program_id, in: :query, type: :string

      response '200', 'CLINIC Dashboard Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/aetc_dashboard' }
        run_test!
      end

      response '404', 'CLINIC Dashboard Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/programs/30/reports/diagnosis_report' do
    get 'Retrieve AETC Diagnosis report' do
      tags TAGS_NAME
      description 'This shows AETC Diagnosis report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string
      parameter name: :age_group, in: :query, type: :string

      response '200', 'AETC Diagnosis Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/aetc_diagnosis' }
        run_test!
      end
    end
  end

  path '/api/v1/programs/30/reports/DISAGGREGATED_DIAGNOSIS' do
    get 'Retrieve AETC DISAGGREGATED Diagnosis report' do
      tags TAGS_NAME
      description 'This shows AETC DISAGGREGATED Diagnosis report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'AETC DISAGGREGATED Diagnosis Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/aetc_dissag_diagnosis' }
        run_test!
      end
    end
  end

  path '/api/v1/programs/30/reports/DISAGGREGATED_DIAGNOSIS' do
    get 'Retrieve AETC DISAGGREGATED Diagnosis report' do
      tags TAGS_NAME
      description 'This shows AETC DISAGGREGATED Diagnosis report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'AETC DISAGGREGATED Diagnosis Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/aetc_dissag_diagnosis' }
        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
