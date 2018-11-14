# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    clazz = clazzname.constantize
    report_generator = clazz.new
    report_generator.generate_report(**kwargs)
  end
end
