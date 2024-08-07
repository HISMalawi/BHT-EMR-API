Radiology::Engine.routes.draw do
    resources :radiology, path: 'api/v1/radiology/radiology_orders'      
    get '/api/v1/radiology/barcode', to: 'radiology#print_order_label'
    get '/api/v1/list_radiology_orders', to: 'radiology#show'
    
end
