# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do
  # def trash_user(username)
  #   user = User.find_by username: username
  #   user&.delete
  # end

  # before do
  #   @auth = login_as 'admin', 'test'
  # end

  # describe 'create' do
  #   create_params = {
  #     username: 'dmr',
  #     password: '1337-haxor',
  #     given_name: 'Dennis',
  #     family_name: 'Ritchie'
  #   }

  #   it 'creates user' do
  #     trash_user create_params[:username]
  #     post :create, create_params, format: :json
  #     expect(response).to have_status_code(:ok)
  #   end

  #   it 'does not create user if already exists' do
  #     UserService.create_user create_params
  #     post :create, create_params, format: :json
  #     expect(response).to have_status_code(:conflict)
  #   end
  # end
end
