# frozen_string_literal: true

require_relative '../../../../lib/auto12epl'

module Lab
  module LabellingService
    ##
    # Prints an order label for order with given accession number.
    class OrderLabel
      attr_reader :order

      def initialize(order_id)
        @order = Lab::LabOrder.find(order_id)
      end

      def print
        # NOTE: The arguments are passed into the method below not in the order
        #       the method expects (eg patient_id is passed to middle_name field)
        #       to retain compatibility with labels generated by the `lab test controller`
        #       application of the NLIMS suite.
        auto12epl.generate_epl(patient.given_name,
                               patient.family_name,
                               patient.nhid,
                               patient.birthdate.strftime('%d/%^b/%Y'),
                               '',
                               patient.gender,
                               '',
                               drawer,
                               '',
                               tests,
                               reason_for_test,
                               order.accession_number,
                               order.accession_number)
      end

      def reason_for_test
        return 'Unknown' unless order.reason_for_test

        short_concept_name(order.reason_for_test.value_coded) || 'Unknown'
      end

      def patient
        return @patient if @patient

        person = Person.find(order.patient_id)
        person_name = PersonName.find_by_person_id(order.patient_id)
        patient_identifier = PatientIdentifier.where(type: PatientIdentifierType.where(name: 'National id'),
                                                     patient_id: order.patient_id)
                                              .first

        @patient = OpenStruct.new(
          given_name: person_name.given_name,
          family_name: person_name.family_name,
          birthdate: person.birthdate,
          gender: person.gender,
          nhid: patient_identifier&.identifier || 'Unknown'
        )
      end

      def drawer
        return 'N/A' if order.concept_id == unknown_concept.concept_id

        drawer_id = User.find(order.discontinued_by || order.creator).person_id
        draw_date = (order.discontinued_date || order.start_date).strftime('%d/%^b/%Y %H:%M:%S')

        name = PersonName.find_by_person_id(drawer_id)
        return "#{name.given_name} #{name.family_name} #{draw_date}" if name

        user = User.find_by_user_id(drawer_id)
        user ? "#{user.username} #{draw_date}" : 'N/A'
      end

      def specimen
        return 'N/A' if order.concept_id == unknown_concept.concept_id

        ConceptName.find_by_concept_id(order.concept_id)&.name || 'Unknown'
      end

      def tests
        tests = order.tests.map do |test|
          name = short_concept_name(test.value_coded) || 'Unknown'

          next 'VL' if name.match?(/Viral load/i)

          name.size > 7 ? name[0..6] : name
        end

        tests.join(', ')
      end

      def short_concept_name(concept_id)
        ConceptName.where(concept_id:)
                   .min_by { |concept| concept.name.size }
                   &.name
      end

      def unknown_concept
        ConceptName.find_by_name('Unknown')
      end

      def auto12epl
        Auto12Epl.new
      end
    end
  end
end