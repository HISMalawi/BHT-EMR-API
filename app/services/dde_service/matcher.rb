# frozen_string_literal: true

class DDEService
  ##
  # Matches local and remote (DDE) people.
  #
  # TODO: Move module to own file
  module Matcher
    class << self
      def find_differences(local_person, remote_person)
        FIELDS_TO_MATCH
          .map { |field| [field, diff_field(field, local_person, remote_person)] }
          .reject { |_field, diff| diff.nil? }
          .each_with_object({}) { |sub_diff, diff| diff[sub_diff[0]] = sub_diff[1] }
      end

      private

      FIELDS_TO_MATCH = %w[given_name family_name birthdate birthdate_estimated gender
                           current_village current_traditional_authority current_district
                           home_village home_traditional_authority home_district
                           npid].freeze

      LOCATION_FIELDS = %w[current_village current_traditional_authority current_district
                           home_village home_traditional_authority home_district].freeze

      def diff_field(field, local_person, remote_person)
        return diff_location(field, local_person, remote_person) if LOCATION_FIELDS.include?(field)

        send("diff_#{field}", local_person, remote_person)
      end

      def diff_given_name(local_person, remote_person)
        local_name = PersonName.find_by_person_id(local_person.person_id)

        return nil if local_name&.given_name&.casecmp?(remote_person['given_name'])

        { local: local_name.given_name, remote: remote_person['given_name'] }
      end

      def diff_family_name(local_person, remote_person)
        local_name = PersonName.find_by_person_id(local_person.person_id)

        return nil if local_name&.family_name&.casecmp?(remote_person['family_name'])

        { local: local_name.given_name, remote: remote_person['family_name'] }
      end

      def diff_birthdate(local_person, remote_person)
        return nil if local_person.birthdate&.to_date == remote_person['birthdate'].to_date

        { local: local_person.birthdate, remote: remote_person['birthdate'] }
      end

      def diff_birthdate_estimated(local_person, remote_person)
        birthdate_estimated = local_person.birthdate_estimated.positive?

        return nil if birthdate_estimated == remote_person['birthdate_estimated']

        { local: birthdate_estimated, remote: remote_person['birthdate_estimated'] }
      end

      def diff_gender(local_person, remote_person)
        return nil if local_person.gender.first.casecmp?(remote_person['gender'].first)

        { local: local_person.gender, remote: remote_person['gender'] }
      end

      def diff_npid(local_person, remote_person)
        npid_type = PatientIdentifierType.where(name: 'National id')
        local_npid = PatientIdentifier.find_by(patient_id: local_person.person_id, type: npid_type)&.identifier

        return nil if local_npid&.casecmp?(remote_person['npid'])

        { local: local_npid, remote: remote_person['npid'] }
      end

      def diff_location(field, local_person, remote_person)
        local_address = PersonAddress.find_by_person_id(local_person.person_id)
        remote_address = remote_person['attributes']

        return nil if local_address.send(field).casecmp?(remote_address[field])

        { local: local_address.send(field), remote: remote_address[field] }
      end

      def current_location_id
        Location.current_health_center.location_id
      end
    end
  end

end
