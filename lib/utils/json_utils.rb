require 'zlib'

module Utils
  module JsonUtils
    def to_compressed_json(obj)
      Zlib::Deflate.deflate(obj)
    end
  end
end