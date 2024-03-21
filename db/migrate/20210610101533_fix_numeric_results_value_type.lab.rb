# frozen_string_literal: true

# This migration comes from lab (originally 20210610095024)
class FixNumericResultsValueType < ActiveRecord::Migration[5.2]
  def up
    results = Lab::LabResult.all.includes(:children)

    ActiveRecord::Base.connection.transaction do
      results.each do |result|
        result.children.each do |measure|
          next unless measure.value_text&.match?(/^[+-]?((\d+(\.\d+)?)|\.\d+)$/)

          puts "Updating result value type for result measure ##{measure.obs_id}"
          measure.value_numeric = measure.value_text
          measure.value_text = nil
          measure.save!
        end
      end
    end
  end

  def down; end
end
