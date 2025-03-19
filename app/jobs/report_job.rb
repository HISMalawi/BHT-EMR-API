# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    User.current = User.unscoped.find(kwargs.delete(:user))
    Location.current = Location.find(User.current.current_location.id)

    clazz = clazzname.constantize
    report_engine = clazz.new
    report_engine.generate_report(**kwargs)
  end
end
