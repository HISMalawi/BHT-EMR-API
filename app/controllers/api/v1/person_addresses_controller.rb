# frozen_string_literal: true

module Api
  module V1
    class PersonAddressesController < ApplicationController
      def create
        address_type = params[:address_type]
        parent_location = params[:parent_location]
        address = params[:addresses_name]

        addAddress address, address_type, parent_location
        render json: { name: address }
      end

      private

      def addAddress(name, address_type, parent_location)
        if address_type == 'TA'
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO traditional_authority
            (name, district_id, creator, date_created)
            VALUES("#{name}", #{parent_location},#{' '}
            #{User.current.id},'#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}');
          SQL

        elsif address_type == 'Village'
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO village
            (name, traditional_authority_id, creator, date_created)
            VALUES("#{name}", #{parent_location},#{' '}
            #{User.current.id},'#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}');
          SQL

        end
      end
    end
  end
end
