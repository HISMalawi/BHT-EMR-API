# frozen_string_literal: true

require 'bantu_soundex'

module NameSearchService
  class << self
    def index_person_name(person_name)
      person_name_code = PersonNameCode.find_by_person_name_id(person_name.id)
      if person_name_code
        update_person_name_code(person_name, person_name_code)
        return person_name_code
      end

      PersonNameCode.create(person_name: person_name,
                            given_name_code: person_name.given_name&.soundex,
                            middle_name_code: person_name.middle_name&.soundex,
                            family_name_code: person_name.family_name&.soundex,
                            family_name2_code: person_name.family_name2&.soundex,
                            family_name_suffix_code: person_name.family_name_suffix&.soundex)
    end

    def update_person_name_code(person_name, person_name_code)
      person_name_code.update(given_name_code: person_name.given_name&.soundex,
                              middle_name_code: person_name.middle_name&.soundex,
                              family_name_code: person_name.family_name&.soundex,
                              family_name2_code: person_name.family_name2&.soundex,
                              family_name_suffix_code: person_name.family_name_suffix&.soundex)
    end

    # Returns all person names that do not have a soundex index.
    def unindexed_person_names
      PersonName.where(
        <<~SQL
          person_name.person_name_id NOT IN (
            SELECT person_name_id FROM person_name_code
          )
        SQL
      )
    end

    def search_partial_person_name(field, value, use_soundex: true, paginator: nil)
      query = PersonName.select(field).distinct
      query = if use_soundex
                query.joins(:person_name_code)\
                     .merge(PersonNameCode.where("#{field}_code like ?", "#{value.soundex}%"))
              else
                query.where("#{field} like ?", "#{value}%")
              end

      query = paginator.call(query) if paginator
      query.order(field).collect(&field)
    end

    def search_full_person_name(filters, use_soundex: true, paginator: nil)
      query = if use_soundex
                search_full_soundex_person_name(**filters)
              else
                search_full_raw_person_name(**filters)
              end

      query = query.order(Arel.sql('given_name, family_name'))

      paginator ? paginator.call(query) : query
    end

    private

    def search_full_soundex_person_name(given_name: nil, family_name: nil, middle_name: nil)
      name_codes = PersonNameCode.all
      name_codes = name_codes.where(given_name_code: given_name.soundex) unless given_name.blank?
      name_codes = name_codes.where(family_name_code: family_name.soundex) unless family_name.blank?
      name_codes = name_codes.where(middle_name_code: middle_name.soundex) unless middle_name.blank?

      PersonName.joins(:person_name_code).merge(name_codes)
    end

    def search_full_raw_person_name(given_name: nil, family_name: nil, middle_name: nil)
      person_names = PersonName.all

      person_names = person_names.where('given_name LIKE ?', "#{given_name}%") unless given_name.blank?
      person_names = person_names.where('family_name LIKE ?', "#{family_name}%") unless family_name.blank?
      person_names = person_names.where('middle_name LIKE ?', "#{middle_name}%") unless middle_name.blank?

      person_names
    end
  end
end
