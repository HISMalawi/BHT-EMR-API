# frozen_string_literal: true

class User < RetirableRecord
  self.table_name = :users
  self.primary_key = :user_id

  cattr_accessor :current

  belongs_to :person, foreign_key: :person_id

  has_many :properties, class_name: 'UserProperty', foreign_key: :user_id
  has_many :user_roles, class_name: 'UserRole'
  has_many :roles, through: :user_roles
  has_many(:names,
           -> { order('person_name.preferred' => 'DESC') },
           class_name: 'PersonName',
           foreign_key: :person_id,
           dependent: :destroy)

  def as_json(options = {})
    super(options.merge(
      except: %i[password salt secret_question secret_answer
                 authentication_token token_expiry_time],
      include: {
        roles: { include: {} },
        person: {
          include: {
            names: {},
            # person_attributes: {},
            # addresses: {}
          }
        }
      }
    ))
  end
end
