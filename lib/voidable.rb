require 'logger'

module Voidable
  def void(reason)
    raise ArgumentError, 'Void reason required' if reason.nil? || reason.empty

    current_user = User.current_user
    LOGGER.warn 'Voiding object outside login session' unless current_user

    return false if voided?

    self.voided = 1
    self.date_voided = Time.now
    self.void_reason = reason
    self.voided_by = current_user ? current_user.id : nil

    exec_after_void_callbacks reason
    save
  end

  def voided?
    raise 'Model not voidable' unless voidable?
    voided != 0
  end

  class << self
    protected

    # Add callbacks do be called after a `void` is successfully executed.
    #
    # @example
    #   >> class Foo < ApplicationRecord
    #   >>   after_void :say_hello, :say_foobar
    #   >>
    #   >>   def say_hello(void_reason)
    #   >>      puts "Hello #{void_reason}"
    #   >>   end
    #   >>
    #   >>   def say_foobar(void_reason)
    #   >>      puts "Foobar #{void_reason}"
    #   >>   end
    #   >> end
    #   >> f = Foo.create.void('Licken Chegs')
    #   => Hello Licken Chegs
    #   => Foobar Licken Chegs
    def after_void(*callbacks)
      after_void_callbacks.push(*callbacks)
    end

    private

    # Returns array of after_void callbacks
    def after_void_callbacks
      # Need variable that's attached to class not instance
      @after_void_callbacks ||= []
    end
  end

  private

  LOGGER = Logger.new STDOUT

  # Executes registered after_void callbacks
  def exec_after_void_callbacks(void_reason)
    after_void_callbacks.each do |callback|
      method(callback).call(void_reason)
    end
  end
end
