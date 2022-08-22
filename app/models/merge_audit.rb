# frozen_string_literal: true

# this is the model managing all merge audits records
class MergeAudit < VoidableRecord
  belongs_to :winner, class_name: 'Patient', foreign_key: 'primary_id', optional: true
  belongs_to :loser, class_name: 'Patient', foreign_key: 'secondary_id', optional: true

  def as_json(options = {})
    super(options.merge(
      include: {
        winner: {
          include: {
            person: {
              include: {
                names: {}
              }
            },
            patient_identifiers: {
              methods: %i[type]
            }
          }
        },
        loser: {
          include: {
            person: {
              include: {
                names: {},
                addresses: {},
                person_attributes: {
                  methods: %i[type]
                }
              }
            },
            patient_identifiers: {
              methods: %i[type]
            }
          }
        }
      },
      methods: %i[looser]
    ))
  end

  def looser
    patient = Patient.unscoped.find(secondary_id).as_json
    patient['person'] = Person.unscoped.find(secondary_id).as_json
    patient['person']['names'] = PersonName.unscoped.where(person_id: secondary_id).as_json
    patient['patient_identifiers'] = PatientIdentifier.unscoped.where(patient_id: secondary_id).as_json(includes: :type)
    patient
  end
end
