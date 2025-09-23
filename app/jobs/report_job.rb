# frozen_string_literal: true

class ReportJob < ApplicationJob
  self.queue_adapter = :async

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    User.current = User.find(kwargs.delete(:user))

    clazz = clazzname.constantize
    report_engine = clazz.new
    report_engine.generate_report(**kwargs)
  end
end
