# frozen_string_literal: true

class RelationshipTypeService
  def find(search_string: nil)
    if search_string.nil?
      query = RelationshipType
    else
      query = RelationshipType.where(
        'a_is_to_b like :search_string or b_is_to_a like :search_string',
        search_string: "%#{search_string}%"
      )
    end

    query.order(:a_is_to_b)
  end
end
