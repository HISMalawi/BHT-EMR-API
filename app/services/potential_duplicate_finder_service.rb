class PotentialDuplicateFinderService
  require 'bantu_soundex'

  MATCH_PARAMS = %i[given_name family_name gender birthdate home_village
                    home_traditional_authority home_district].freeze
  
  SOUNDEX_MATCH_PARAMS = %i[home_village home_traditional_authority home_district].freeze

  def self.duplicates_finder
    # Get all patients along with the necessary attributes
    global_duplicates = []
    already_checked = Set.new
    threshold_percent = YAML.load(File.read("#{Rails.root}/config/application.yml"), aliases: true)['deduplication']['match_percentage']

    fetch_patients.each do |primary_patient|

      potential_duplicates = []
      fuzzy_potential_duplicates = []
      soundex_duplicates = []
      soundex_potentials = []

      fetch_patients(use_batches: true).each do |batch|
        batch.each do |potential_duplicate|

        next if already_checked.include?(primary_patient.person_id)

        fuzzy_potential_duplicates << fuzzy_match(potential_duplicate, primary_patient, already_checked,
                                                  threshold_percent)
      
        soundex_duplicates << soundex_potential_duplicates(primary_patient, potential_duplicate, already_checked)
        

        soundex_potentials << soundex_fuzzy_match(soundex_duplicates.flatten!,
                                                  primary_patient, already_checked, threshold_percent) unless soundex_duplicates.flatten.blank?
        all_potential_duplicates = (fuzzy_potential_duplicates + soundex_potentials).uniq.flatten

        all_potential_duplicates.each { |match| already_checked << match.person_id }

        potential_duplicates << format_potential_duplicates(primary_patient, all_potential_duplicates)

        already_checked << primary_patient.person_id
        end
      end
      save_matching(potential_duplicates)
      global_duplicates << potential_duplicates unless potential_duplicates.empty?
    end

    global_duplicates
  end

  private

    def self.fetch_patients(use_batches: false)
      patients_query = Person.joins(:names, :addresses)
                             .joins(patient: :patient_programs)
                             .where(patient_program: { program_id: 33, voided: 0 })
                             .select('person.person_id, person.birthdate, person.gender,
                                      person_name.given_name, person_name.family_name, 
                                      person_name.middle_name, person_address.address2 AS home_district,
                                      person_address.neighborhood_cell AS home_village, 
                                      person_address.county_district AS home_traditional_authority')
      if use_batches
        patients_query.in_batches(of: 1000)
      else
        patients_query.find_each
      end
    end
  
    def self.perform_soundex_matching(primary_patient, secondary_patient)
      primary_patient.given_name.soundex == secondary_patient.given_name.soundex &&
        primary_patient.middle_name.soundex == secondary_patient.middle_name.soundex &&
        primary_patient.family_name.soundex == secondary_patient.family_name.soundex
    end

    def self.format_potential_duplicates(primary_patient, final_potential_duplicates)
      {
        primary_patient_id: primary_patient.person_id,
        given_name: primary_patient.given_name,
        family_name: primary_patient.family_name,
        duplicates: final_potential_duplicates.map do |match|
          {
            secondary_patient_id: match.person_id,
            given_name: match.given_name,
            family_name: match.family_name,
            match_percentage: (WhiteSimilarity.similarity(concat_person_attributes(primary_patient),
                                                          concat_person_attributes(match)) * 100).round(0)
          }
        end
      }
    end

    def self.concat_person_attributes(person)
      MATCH_PARAMS.map { |attribute| person.send(attribute) }.join
    end

    def self.concat_home_attributes(person)
      SOUNDEX_MATCH_PARAMS.map { |attribute| person.send(attribute) }.join
    end

    def self.soundex_fuzzy_match(patients, primary_patient, already_checked, threshold_percent)
      # Here we just do a fuzzy match comparision on the person attributes DOB,gender home_village,
      # home_traditional_authority, home_district
      # Because we have already concluded that the names sound alike and probablity of being same person is high
      patients.select do |potential_duplicate|
        potential_duplicate.person_id != primary_patient['person_id'] &&
        !already_checked.include?(potential_duplicate.person_id) &&
        (concat_home_attributes(primary_patient) == concat_home_attributes(potential_duplicate)) == 100 # We are only interested in records with exact match on home_village, home_traditional_authority, home_district
      end
    end

    def self.fuzzy_match(patients, primary_patient, already_checked, threshold_percent)
      patients.select do |potential_duplicate|
        potential_duplicate.person_id != primary_patient.person_id &&
          !already_checked.include?(potential_duplicate.person_id) &&
          (WhiteSimilarity.similarity(concat_person_attributes(primary_patient),
                                      concat_person_attributes(potential_duplicate)) * 100) >= threshold_percent
      end
    end

    def self.soundex_potential_duplicates(primary_patient, patients, already_checked)
      patients.select do |client|
        client.person_id != primary_patient.person_id &&
          perform_soundex_matching(primary_patient, client) &&
          !already_checked.include?(client.person_id)
      end
    end

    def self.add_match_type(clients, match)
      clients.map do |client|
        client[:match_type] = match
      end
    end

    def self.save_matching(duplicate_matches)
      ActiveRecord::Base.transaction do
        duplicate_matches.each do |client|
          primary_patient_id = client[:primary_patient_id]

          client[:duplicates].each do |client_b|
            secondary_patient_id = client_b[:secondary_patient_id]
            match_percentage = client_b[:match_percentage]

            match_exists = PotentialDuplicate.where(
              '(patient_id_a = :primary_id AND patient_id_b = :secondary_id) OR
              (patient_id_a = :secondary_id AND patient_id_b = :primary_id)',
              primary_id: primary_patient_id, secondary_id: secondary_patient_id
            ).exists?

            next if match_exists

            PotentialDuplicate.create!(
              patient_id_a: primary_patient_id,
              patient_id_b: secondary_patient_id,
              match_percentage:
            )
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to save patient match: #{e.message}")
    end
end