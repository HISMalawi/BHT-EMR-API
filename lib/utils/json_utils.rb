# frozen_string_literal: true

require 'zlib'

module Utils
  module JsonUtils
    def to_compressed_json(obj)
      # TODO: make this work
      # Zlib::Deflate.deflate(obj)
      obj
    end
  end
end
