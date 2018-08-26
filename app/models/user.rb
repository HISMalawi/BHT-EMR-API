# frozen_string_literal: true

class User < ApplicationRecord
  self.table_name = :users
  self.primary_key = :user_id

  cattr_accessor :current

  belongs_to :person, foreign_key: :person_id

  has_many :properties, class_name: 'UserProperty', foreign_key: :user_id
  has_many :user_roles, foreign_key: :user_id, dependent: :delete_all
  has_many(:names,
           -> { order('person_name.preferred' => 'DESC') },
           class_name: 'PersonName',
           foreign_key: :person_id,
           dependent: :destroy)

  def as_json(options = {})
    super(options.merge(
      except: %i[password salt],
      include: {
        role: { include: { privileges: {} } },
        person: {
          include: {
            person_names: {},
            person_attributes: {},
            person_addresses: {}
          }
        }
      }
    ))
  end
end
