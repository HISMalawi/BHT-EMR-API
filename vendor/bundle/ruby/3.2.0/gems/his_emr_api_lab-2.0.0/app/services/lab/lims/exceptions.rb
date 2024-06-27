# frozen_string_literal: true

module Lab
  module Lims
    class Exceptions < StandardError; end
    class LimsException < StandardError; end
    class DuplicateNHID < LimsException; end
    class MissingAccessionNumber < LimsException; end
    class UnknownSpecimenType < LimsException; end
    class UnknownTestType < LimsException; end
  end
end
