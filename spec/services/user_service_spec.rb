# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserService do
  let(:programs) { Program.all}
  let(:user_service) {UserService.new}
  
  describe "Create User" do
    it "creates user associated with one more programs" do
        programs
        program_ids = []
        programs.each do |pg|
          program_ids << pg.program_id
        end

        roles = ["Clinician", "Doctor", "Nurse"]

        user = UserService.create_user(
                              username: 'jdoe', 
                              password: 'test123',
                              given_name: 'John',
                              family_name: 'Doe',
                              roles: roles,
                              programs: program_ids)
        
        expect(user)
        
    end
  end
end
