# frozen_string_literal: true

##
# Log to multiple streams.
#
# The 'logger' module does not provide a logger that can log
# to multiple streams at once hence this hack. This class
# bundles multiple loggers so that they can be treated as
# one.
#
# Example:
#   >>> logger = LoggerMultiplexor.new(STDOUT, 'development.log')
#   >>> logger.info('Hello') # Logs 'Hello' to both streams
class LoggerMultiplexor
  def initialize(*loggers)
    @loggers = loggers.map do |stream|
      if stream.is_a?(Logger) || stream.is_a?(LoggerMultiplexor)
        stream
      else
        Logger.new(stream)
      end
    end
  end

  def method_missing(method_name, *args)
    @loggers.each { |logger| logger.method(method_name).call(*args) }
  end

  def respond_to_missing?(method_name)
    @loggers.all? { |logger| logger.respond_to_missing?(method_name) }
  end
end
