# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NameSearchService do
  describe :index_person_name do
    it 'creates PersonNameCode for person_name' do
      person_name = create(:person_name)
      person_name_code = NameSearchService.index_person_name(person_name)

      expect(person_name_code.id).not_to be_nil
      expect(person_name_code.person_name_id).to eq(person_name.id)
    end

    it 'generates person_name soundex values' do
      person_name = create(:person_name)
      person_name_code = NameSearchService.index_person_name(person_name)

      expect(person_name_code.given_name_code).to eq(person_name.given_name.soundex)
      expect(person_name_code.family_name_code).to eq(person_name.family_name.soundex)
      expect(person_name_code.middle_name_code).to eq(person_name.middle_name.soundex)
    end
  end

  describe :unindexed_person_names do
    it 'retrieves all person names that do not have person name codes' do
      initial_unindexed_names = NameSearchService.unindexed_person_names
      initial_unindexed_names[0] # Bypass ActiveRecord's lazy evaluation of queries

      unindexed_names = create_list(:person_name, 5)

      create_list(:person_name, 10).collect do |name|
        NameSearchService.index_person_name(name)
      end

      unindexed_names_found = NameSearchService.unindexed_person_names
      expect(unindexed_names_found.size).to eq(unindexed_names.size + initial_unindexed_names.size)
      unindexed_names_found.each do |name|
        next if initial_unindexed_names.include?(name)

        expect(unindexed_names).to include(name)
      end
    end

    it 'does not retrieve indexed names' do
      create_list(:person_name, 5)

      indexed_names = create_list(:person_name, 10).collect do |name|
        NameSearchService.index_person_name(name)
        name
      end

      unindexed_names_found = NameSearchService.unindexed_person_names
      expect(unindexed_names_found.size).not_to eq(indexed_names.size)
      unindexed_names_found.each do |name|
        expect(indexed_names).not_to include(name)
      end
    end
  end

  describe :search_partial_person_name do
    it 'matches given_name by soundex' do
      target_name_set = %w[Fosta Fosita Fositala Foster Fostala]
      control_name_set = %w[Judas Thanos Death Jonas Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, given_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:given_name, 'Fosta')
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end

    it 'matches given_name by globbing when soundex is disabled' do
      target_name_set = %w[Fosta Fostala]
      control_name_set = %w[Fosita Fositala Foster Judas Thanos Death Jonas
                            Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, given_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:given_name, 'Fosta', use_soundex: false)
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end

    it 'matches family_name by soundex' do
      target_name_set = %w[Fosta Fosita Fositala Foster Fostala]
      control_name_set = %w[Judas Thanos Death Jonas Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, family_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:family_name, 'Fosta')
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end

    it 'matches family_name by globbing when soundex is disabled' do
      target_name_set = %w[Fosta Fostala]
      control_name_set = %w[Fosita Fositala Foster Judas Thanos Death Jonas
                            Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, family_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:family_name, 'Fosta', use_soundex: false)
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end

    it 'matches middle_name by soundex' do
      target_name_set = %w[Fosta Fosita Fositala Foster Fostala]
      control_name_set = %w[Judas Thanos Death Jonas Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, middle_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:middle_name, 'Fosta')
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end

    it 'matches middle_name by globbing when soundex is disabled' do
      target_name_set = %w[Fosta Fostala]
      control_name_set = %w[Fosita Fositala Foster Judas Thanos Death Jonas
                            Frodo Gosling Matz]

      (target_name_set + control_name_set).each do |name|
        name = create(:person_name, middle_name: name)
        NameSearchService.index_person_name(name)
      end

      names = NameSearchService.search_partial_person_name(:middle_name, 'Fosta', use_soundex: false)
      expect(names.size).to eq(target_name_set.size)
      names.each { |name| expect(target_name_set).to include(name) }
    end
  end
end
