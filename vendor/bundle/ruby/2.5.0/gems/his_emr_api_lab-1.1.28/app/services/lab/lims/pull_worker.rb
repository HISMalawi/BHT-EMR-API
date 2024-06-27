# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Pulls orders from a Lims API object and saves them to the local database.
    class PullWorker
      attr_reader :lims_api

      include Utils # for logger

      LIMS_LOG_PATH = Rails.root.join('log', 'lims')

      def initialize(lims_api)
        @lims_api = lims_api
      end

      ##
      # Pulls orders from the LIMS queue and writes them to the local database
      def pull_orders(batch_size: 10_000, **kwargs)
        logger.info("Retrieving LIMS orders starting from #{last_seq}")

        lims_api.consume_orders(from: last_seq, limit: batch_size, **kwargs) do |order_dto, context|
          logger.debug("Retrieved order ##{order_dto[:tracking_number]}: #{order_dto}")

          patient = find_patient_by_nhid(order_dto[:patient][:id])
          unless patient
            logger.debug("Discarding order: Non local patient ##{order_dto[:patient][:id]} on order ##{order_dto[:tracking_number]}")
            order_rejected(order_dto, "Patient NPID, '#{order_dto[:patient][:id]}', didn't match any local NPIDs")
            next
          end

          if order_dto[:tests].empty?
            logger.debug("Discarding order: Missing tests on order ##{order_dto[:tracking_number]}")
            order_rejected(order_dto, 'Order is missing tests')
            next
          end

          diff = match_patient_demographics(patient, order_dto['patient'])
          if diff.empty?
            save_order(patient, order_dto)
            order_saved(order_dto)
          else
            save_failed_import(order_dto, 'Demographics not matching', diff)
          end

          update_last_seq(context.current_seq)
        rescue Lab::Lims::DuplicateNHID
          logger.warn("Failed to import order due to duplicate patient NHID: #{order_dto[:patient][:id]}")
          save_failed_import(order_dto, "Duplicate local patient NHID: #{order_dto[:patient][:id]}")
        rescue MissingAccessionNumber
          logger.warn("Failed to import order due to missing accession number: #{order_dto[:_id]}")
          save_failed_import(order_dto, 'Order missing tracking number')
        rescue LimsException => e
          logger.warn("Failed to import order due to #{e.class} - #{e.message}")
          save_failed_import(order_dto, e.message)
        end
      end

      protected

      def order_saved(order_dto); end

      def order_rejected(order_dto, message); end

      def last_seq
        File.open(last_seq_path, File::RDONLY | File::CREAT, 0o644) do |fin|
          data = fin.read&.strip
          return nil if data.blank?

          return data
        end
      end

      def update_last_seq(last_seq)
        File.open(last_seq_path, File::WRONLY | File::CREAT, 0o644) do |fout|
          fout.flock(File::LOCK_EX)

          fout.write(last_seq.to_s)
        end
      end

      private

      def find_patient_by_nhid(nhid)
        national_id_type = PatientIdentifierType.where(name: ['National id', 'Old Identification Number'])
        identifiers = PatientIdentifier.where(type: national_id_type, identifier: nhid)
                                       .joins('INNER JOIN person ON person.person_id = patient_identifier.patient_id AND person.voided  = 0')
        if identifiers.count.zero?
          identifiers = PatientIdentifier.unscoped
                                         .where(voided: 1, type: national_id_type, identifier: nhid)
                                         .joins('INNER JOIN person ON person.person_id = patient_identifier.patient_id AND person.voided  = 0')
        end

        # Joining to person above to ensure that the person is not voided,
        # it was noted at one site that there were some people that were voided
        # upon merging but the patient and patient_identifier was not voided

        return nil if identifiers.count.zero?

        patients = Patient.where(patient_id: identifiers.select(:patient_id))
                          .distinct(:patient_id)
                          .all

        raise Lab::Lims::DuplicateNHID, "Duplicate National Health ID: #{nhid}" if patients.size > 1

        patients.first
      end

      ##
      # Matches a local patient's demographics to a LIMS patient's demographics
      def match_patient_demographics(local_patient, lims_patient)
        diff = {}
        person = Person.find(local_patient.id)
        person_name = PersonName.find_by_person_id(local_patient.id)

        unless (person.gender.blank? && lims_patient['gender'].blank?)\
          || person.gender&.first&.casecmp?(lims_patient['gender']&.first)
          diff[:gender] = { local: person.gender, lims: lims_patient['gender'] }
        end

        unless names_match?(person_name&.given_name, lims_patient['first_name'])
          diff[:given_name] = { local: person_name&.given_name, lims: lims_patient['first_name'] }
        end

        unless names_match?(person_name&.family_name, lims_patient['last_name'])
          diff[:family_name] = { local: person_name&.family_name, lims: lims_patient['last_name'] }
        end

        diff
      end

      def names_match?(name1, name2)
        name1 = name1&.gsub(/'/, '')&.strip
        name2 = name2&.gsub(/'/, '')&.strip

        return true if name1.blank? && name2.blank?

        return false if name1.blank? || name2.blank?

        name1.casecmp?(name2)
      end

      def save_order(patient, order_dto)
        raise MissingAccessionNumber if order_dto[:tracking_number].blank?

        logger.info("Importing LIMS order ##{order_dto[:tracking_number]}")
        mapping = find_order_mapping_by_lims_id(order_dto[:_id])

        ActiveRecord::Base.transaction do
          if mapping
            order = update_order(patient, mapping.order_id, order_dto)
            mapping.update(pulled_at: Time.now)
          else
            order = create_order(patient, order_dto)
            mapping = LimsOrderMapping.create(lims_id: order_dto[:_id],
                                              order_id: order['id'],
                                              pulled_at: Time.now,
                                              revision: order_dto['_rev'])
          end

          order
        end
      end

      def create_order(patient, order_dto)
        logger.debug("Creating order ##{order_dto['_id']}")
        order = OrdersService.order_test(order_dto.to_order_service_params(patient_id: patient.patient_id))
        update_results(order, order_dto['test_results']) unless order_dto['test_results'].empty?

        order
      end

      def update_order(patient, order_id, order_dto)
        logger.debug("Updating order ##{order_dto['_id']}")
        order = OrdersService.update_order(order_id, order_dto.to_order_service_params(patient_id: patient.patient_id)
                                                              .merge(force_update: 'true'))
        update_results(order, order_dto['test_results']) unless order_dto['test_results'].empty?

        order
      end

      def update_results(order, lims_results)
        logger.debug("Updating results for order ##{order[:accession_number]}: #{lims_results}")
        
        lims_results.each do |test_name, test_results|
          test = find_test(order['id'], test_name)
          unless test
            logger.warn("Couldn't find test, #{test_name}, in order ##{order[:id]}")
            next
          end
          
          next if test.result || test_results['results'].blank?

          measures = test_results['results'].map do |indicator, value|
            measure = find_measure(order, indicator, value)
            next nil unless measure

            measure
          end
          
          measures = measures.compact
          next if measures.empty?

          creator = format_result_entered_by(test_results['result_entered_by'])

          ResultsService.create_results(test.id,  { provider_id: User.current.person_id,
                                                    date: Utils.parse_date(test_results['date_result_entered'], order[:order_date].to_s),
                                                    comments: "LIMS import: Entered by: #{creator}",
                                                    measures: measures } )
        end
      end

      def find_test(order_id, test_name)
        test_name = Utils.translate_test_name(test_name)
        test_concept = Utils.find_concept_by_name(test_name)
        raise "Unknown test name, #{test_name}!" unless test_concept

        LabTest.find_by(order_id: order_id, value_coded: test_concept.concept_id)
      end

      def find_measure(_order, indicator_name, value)
        indicator = Utils.find_concept_by_name(indicator_name)
        unless indicator
          logger.warn("Result indicator #{indicator_name} not found in concepts list")
          return nil
        end

        value_modifier, value, value_type = parse_lims_result_value(value)
        return nil if value.blank?

        ActiveSupport::HashWithIndifferentAccess.new(
          indicator: { concept_id: indicator.concept_id },
          value_type: value_type,
          value: value_type == 'numeric' ? value.to_f : value,
          value_modifier: value_modifier.blank? ? '=' : value_modifier
        )
      end

      def parse_lims_result_value(value)
        value = value['result_value']&.strip
        return nil, nil, nil if value.blank?

        match = value&.match(/^(>|=|<|<=|>=)(.*)$/)
        return nil, value, guess_result_datatype(value) unless match

        [match[1], match[2].strip, guess_result_datatype(match[2])]
      end

      def guess_result_datatype(result)
        return 'numeric' if result.strip.match?(/^[+-]?((\d+(\.\d+)?)|\.\d+)$/)

        'text'
      end

      def format_result_entered_by(result_entered_by)
        first_name = result_entered_by['first_name']
        last_name = result_entered_by['last_name']
        phone_number = result_entered_by['phone_number']
        id = result_entered_by['id'] # Looks like a user_id of some sort

        "#{id}:#{first_name} #{last_name}:#{phone_number}"
      end

      def save_failed_import(order_dto, reason, diff = nil)
        logger.info("Failed to import LIMS order ##{order_dto[:tracking_number]} due to '#{reason}'")
        LimsFailedImport.create!(lims_id: order_dto[:_id],
                                 tracking_number: order_dto[:tracking_number],
                                 patient_nhid: order_dto[:patient][:id],
                                 reason: reason,
                                 diff: diff&.to_json)
      end

      def last_seq_path
        LIMS_LOG_PATH.join('last_seq.dat')
      end

      def find_order_mapping_by_lims_id(lims_id)
        mapping = Lab::LimsOrderMapping.find_by(lims_id: lims_id)
        return nil unless mapping

        return mapping if Lab::LabOrder.where(order_id: mapping.order_id).exists?

        mapping.destroy
        nil
      end
    end
  end
end
