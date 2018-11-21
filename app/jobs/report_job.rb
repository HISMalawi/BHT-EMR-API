# frozen_string_literal: true

class ReportJob < ApplicationJob
  queue_as :default

  def perform(clazzname, kwargs)
    logger.debug("Running report job #{clazzname}(#{kwargs})")

    user_id = kwargs[:user]
    kwargs.delete(:user)
    User.current = User.find(user_id)

    clazz = clazzname.constantize
    report_engine = clazz.new
    report_engine.generate_report(**kwargs)
  end
end
