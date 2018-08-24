# frozen_string_literal: true

require 'logger'

module Voidable
  def void(reason)
    raise ArgumentError, 'Void reason required' if reason.nil? || reason.empty?

    user = User.current_user
    Rails.logger.warn 'Voiding object outside login session' unless user

    return false if voided?

    self.voided = 1
    self.date_voided = Time.now
    self.void_reason = reason
    self.voided_by = user ? user.id : nil

    _exec_after_void_callbacks reason
    save
  end

  def voided?
    raise 'Model not voidable' unless voidable?
    voided != 0
  end

  def voidable?
    respond_to? :voided
  end

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
  def self.after_void(*callbacks)
    _after_void_callbacks.push(*callbacks)
  end

  # Executes registered after_void callbacks
  def _exec_after_void_callbacks(void_reason)
    _after_void_callbacks.each do |callback|
      method(callback).call(void_reason)
    end
  end

  # Returns array of after_void callbacks
  def self._after_void_callbacks
    # Need variable that's attached to class not instance
    @after_void_callbacks ||= []
  end
end
