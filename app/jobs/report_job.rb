# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    clazz = clazzname.constantize
    report_engine = clazz.new
    report_engine.generate_report(**kwargs)
  end
end
