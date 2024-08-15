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

      PersonNameCode.create(person_name:,
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

      if use_soundex
        full_soundex = value.soundex
        partial_soundex = value[0..2].soundex

        query = query.joins(:person_name_code)
                     .where("#{field}_code LIKE ? OR #{field}_code LIKE ?", "#{full_soundex}%", "#{partial_soundex}%")
      else
        query = query.where("#{field} LIKE ?", "#{value}%")
      end

      query = paginator.call(query) if paginator
      query.order(field).collect(&field)
    end


    def search_full_person_name(filters, use_soundex: true, paginator: nil)
      raw_query = search_full_raw_person_name(**filters)
      raw_results = paginator ? paginator.call(raw_query) : raw_query

      if raw_results.exists?
         raw_results
      else
        soundex_query = search_full_soundex_person_name(**filters)
        paginator ? paginator.call(soundex_query) : soundex_query
      end
    end

    private

    def search_full_soundex_person_name(given_name: nil, family_name: nil, middle_name: nil)
      name_codes = PersonNameCode.all
      unless given_name.blank?
        full_soundex = given_name.soundex
        partial_soundex = given_name[0..2].soundex
        name_codes = name_codes.where('given_name_code LIKE ? OR given_name_code LIKE ?', "#{full_soundex}%", "#{partial_soundex}%")
      end

      unless family_name.blank?
        full_soundex = family_name.soundex
        partial_soundex = family_name[0..2].soundex
        name_codes = name_codes.where('family_name_code LIKE ? OR family_name_code LIKE ?', "#{full_soundex}%", "#{partial_soundex}%")
      end

      unless middle_name.blank?
        full_soundex = middle_name.soundex
        partial_soundex = middle_name[0..2].soundex
        name_codes = name_codes.where('middle_name_code LIKE ? OR middle_name_code LIKE ?', "#{full_soundex}%", "#{partial_soundex}%")
      end

      PersonName.joins(:person_name_code).merge(name_codes)
      
    end

    def search_full_raw_person_name(given_name: nil, family_name: nil, middle_name: nil, gender: nil)
      PersonName.joins([person: {patient: :encounters}]).where(
        '(given_name LIKE ? OR given_name IS NULL) AND
         (family_name LIKE ? OR family_name IS NULL) AND
         (middle_name LIKE ? OR middle_name IS NULL) AND
         (gender LIKE ? OR gender IS NULL)',
        "#{given_name}%", "#{family_name}%", "#{middle_name}%", "#{gender}%"
      ).order(Arel.sql("CASE WHEN encounter.location_id = #{User.current.location_id} THEN 0 ELSE 1 END,
                        given_name, family_name"))
    end
  end
end
