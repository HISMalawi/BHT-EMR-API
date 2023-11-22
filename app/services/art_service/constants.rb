# frozen_string_literal: true

module ArtService
  module Constants
    PROGRAM_ID = 1

    module States
      ON_ANTIRETROVIRALS = 7
      DEFAULTED = 12
      DIED = 3
      TRANSFERRED_OUT = 2
      TREATMENT_STOPPED = 6

      TERMINALS = [DEFAULTED, DIED, TRANSFERRED_OUT, TREATMENT_STOPPED].freeze
    end
  end
end
