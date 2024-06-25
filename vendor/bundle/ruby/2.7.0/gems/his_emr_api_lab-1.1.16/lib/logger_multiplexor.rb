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
    if respond_to_missing?(method_name)
      @loggers.each { |logger| logger.send(method_name, *args) }
    else
      super
    end
  end

  def respond_to_missing?(method_name)
    @loggers.all? do |logger|
      logger.respond_to?(method_name)
    end
  end
end
