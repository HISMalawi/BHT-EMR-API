# frozen_string_literal: true

require 'logger_multiplexor'

Rails.logger = LoggerMultiplexor.new(Rails.root.join('log/lims-sync.log'), $stdout)
Lab::Lims::Worker.start
