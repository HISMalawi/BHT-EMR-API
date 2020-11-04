# frozen_string_literal: true

class User < RetirableRecord
  self.table_name = :users
  self.primary_key = :user_id

  belongs_to :person, foreign_key: :person_id

  has_many :properties, class_name: 'UserProperty', foreign_key: :user_id
  has_many :user_roles, class_name: 'UserRole'
  has_many :roles, through: :user_roles
  has_many :user_programs
  has_many :programs, through: :user_programs #User programs
  has_many(:names,
           -> { order('person_name.preferred' => 'DESC') },
           class_name: 'PersonName',
           foreign_key: :person_id,
           dependent: :destroy)

  def active?
    deactivated_on.nil?
  end

  def self.current
    Thread.current['current_user']
  end

  def self.current=(user)
    Thread.current['current_user'] = user
  end

  def as_json(options = {})
    super(options.merge(
      except: %i[password salt secret_question secret_answer
                 authentication_token token_expiry_time],
      include: {
        roles: { include: {} },
        programs: {},
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
