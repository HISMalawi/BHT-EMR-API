require "audited"

Audited::Railtie.initializers.each(&:run)