# frozen_string_literal: true

class ConceptNumeric < ApplicationRecord
  self.table_name = :concept_numeric
  self.primary_key = :concept_id

  has_one :concept, foreign_key: :concept_id, dependent: :destroy

  # def options
  #   result = {}
  #   result[:absoluteMin] = low_absolute unless low_absolute.blank?
  #   result[:absoluteMax] = hi_absolute unless hi_absolute.blank?
  #   result[:min] = low_critical unless low_critical.blank?
  #   result[:max] = hi_critical unless hi_critical.blank?
  #   result[:units] = units unless units.blank?
  #   result
  # end

  # def precision
  #   result = {}
  #   if precise == 1
  #     result[:validationRule] = "([0-9]+\\.[0-9])|Unknown$"
  #     result[:validationMessage] = "You must enter a decimal between 0 and 9 (for example: 54<b>.6</b>)"
  #     result[:tt_pageStyleClass] = "Numeric NumbersOnlyWithDecimal"
  #   end
  #   result
  # end
end
