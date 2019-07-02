# frozen_string_literal: true

require 'bantu_soundex'

module NameSearchService
  class << self
    def index_person_name(person_name)
      person_name_code = PersonNameCode.find_by_person_name_id(person_name.id)
      if person_name_code
        update_person_name_code(person_name_code, person_name)
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
      query.collect(&field)
    end

    def search_full_person_name(given_name, family_name, use_soundex: true, paginator: nil)
      query = if use_soundex
                sub_query = PersonNameCode.where('given_name_code LIKE ? AND family_name_code LIKE ?',
                                                 "#{given_name.soundex}%", "#{family_name.soundex}%")
                PersonName.joins(:person_name_code).merge(sub_query)
              else
                PersonName.where('given_name LIKE ? AND family_name LIKE ?', "#{given_name}%", "#{family_name}%")
              end

      paginator ? paginator.call(query) : query
    end
  end
end
