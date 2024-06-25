# frozen_string_literal: true

Lab::Engine.routes.draw do
  resources :orders, path: 'api/v1/lab/orders'
  resources :tests, path: 'api/v1/lab/tests', except: %i[update] do # ?pending=true to select tests without results?
    resources :results, only: %i[index create destroy]
  end

  get 'api/v1/lab/labels/order', to: 'labels#print_order_label'

  # Metadata
  # TODO: Move the following to namespace /concepts
  resources :specimen_types, only: %i[index], path: 'api/v1/lab/specimen_types'
  resources :test_result_indicators, only: %i[index], path: 'api/v1/lab/test_result_indicators'
  resources :test_types, only: %i[index], path: 'api/v1/lab/test_types'
  resources :reasons_for_test, only: %i[index], path: 'api/v1/lab/reasons_for_test'
end
