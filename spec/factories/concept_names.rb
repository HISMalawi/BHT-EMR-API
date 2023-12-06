# frozen_string_literal: true

FactoryBot.define do
  factory :concept_name do
    # Ought to be using Faker or something for the following
    # but can't add a new gem without forcing `bundle install`
    # in none networked environments.
    name { (0...20).map { (65 + rand(26)).chr }.join }
    date_created { Time.now }
    creator { 1 }
  end
end
