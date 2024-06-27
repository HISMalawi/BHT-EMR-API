# frozen_string_literal: true

module Lab
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
