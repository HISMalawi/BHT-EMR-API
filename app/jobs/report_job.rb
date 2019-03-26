# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    lock = kwargs.delete(:lock)

    User.current = User.find(kwargs.delete(:user))
    type = ReportType.find(kwargs.delete(:type))

    clazz = clazzname.constantize
    report_engine = clazz.new
    report_engine.generate_report(type: type, **kwargs)
  ensure
    ReportService.release_report_lock(lock)
  end
end
