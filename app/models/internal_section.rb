# frozen_string_literal: true

class InternalSection < VoidableRecord
  # validate presence of name and name is unique
  validates :name, presence: true, uniqueness: true
end
