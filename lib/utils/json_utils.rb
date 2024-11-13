require 'zlib'

module JsonUtils
  class << self
    def to_compressed_json(obj)
      json_data = obj.to_json
      Zlib::Deflate.deflate(json_data)
    end
  end
end