# frozen_string_literal: true

class UnprocessableEntityError < ApplicationError
  attr_reader :entity

  def add_entity(entity)
    @entity = entity
    self
  end
end
