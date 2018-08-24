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

  def self.random_string(len)
    #generat a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
end
