class UserVillage < ApplicationRecord
    self.table_name = :user_villages
    self.primary_key = :user_village_id


    has_many  :user, foreign_key: :user_id
    has_many  :village, foreign_key: :village_id 

end