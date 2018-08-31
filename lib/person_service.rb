# frozen_string_literal: true

require 'securerandom'

module PersonService
  def create_person(params)
    Person.create(
      gender: params[:gender],
      birthdate: params[:birthdate],
      birthdate_estimated: params[:birthdate_estimated],
      creator: User.current.id
    )
  end

  def create_person_name(person, params)
    PersonName.create(
      person: person,
      given_name: params[:given_name],
      family_name: params[:family_name],
      middle_name: params[:middle_name],
      creator: User.current.id,
      # HACK: Manually set uuid because db requires it but has no default
      uuid: SecureRandom.uuid
    )
  end

  def create_person_address(person, params)
    PersonAddress.create(
      person: person,
      state_province: params[:current_district],
      city_village: params[:current_village],
      township_division: params[:current_traditional_authority],
      address2: params[:home_district],
      neighborhood_cell: params[:home_village],
      county_district: params[:home_traditional_authority],
      creator: User.current.id
    )
  end

  # def create_person_attributes(person, person_attributes)
  #   person_attributes.collect do |attr, value|
  #     s_attr = attr.to_s.gsub(/_+/, ' ')
  #     attr_type = PersonAttributeType.where(name: s_attr).first
  #     unless attr_type
  #       Rails.logger.warn "Invalid person attribute type: #{attr}"
  #       next nil
  #     end
  #     PersonAttribute.create(
  #       person: person,
  #       type: attr_type,
  #       value: value,
  #       creator: User.current.id,
  #       # HACK: Manually set uuid because db requires it but has no default
  #       uuid: SecureRandom.uuid
  #     )
  #   end
  # end
end
