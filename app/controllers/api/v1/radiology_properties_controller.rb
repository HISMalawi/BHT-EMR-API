require 'json'
class Api::V1::RadiologyPropertiesController < ApplicationController


  def create(success_response_status: :created)
    path, value = params.require %i[path property_value]

      file = File.read path
      hash = JSON.parse file
      if value == 'true'
        hash['encounters']['radiology orders']['available'] = true
      else
        hash['encounters']['radiology orders']['available'] = false
      end
      File.open path , "w" do |f|
        f.puts JSON.pretty_generate hash
      end
      render json: value, status: success_response_status
  end


end
