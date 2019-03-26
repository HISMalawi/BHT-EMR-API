# frozen_string_literal: true

# I do not know what the purpose of this is but it's used by the
# frontenders somehow... Take it as it is, don't ask questions.
class Api::V1::WeightForHeightController < ApplicationController
  def index
    render json: WeightForHeight.patient_weight_for_height_values
  end
end
