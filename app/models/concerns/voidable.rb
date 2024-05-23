# frozen_string_literal: true

# Blesses ActiveRecord models with a voidable behaviour
module Voidable
  extend ActiveSupport::Concern

  # Contains Voidable's instance methods
  def void(reason, skip_after_void: false)
    raise ArgumentError, 'Void reason required' if reason.nil? || reason.empty?

    user = User.current
    Rails.logger.warn 'Voiding object outside login session' unless user

    clazz = self.class
    clazz._update_voidable_field self, :voided, 1
    clazz._update_voidable_field self, :date_voided, Time.now
    clazz._update_voidable_field self, :void_reason, reason
    clazz._update_voidable_field self, :voided_by, user&.user_id

    save!(validate: false)

    clazz._exec_after_void_callbacks self, reason unless skip_after_void

    true
  end

  def voided?
    raise 'Model not voidable' unless voidable?

    voided != 0
  end

  def voidable?
    respond_to? self.class._voidable_field(:voided)
  end

  # Contains voidable's class methods `after_void` which is public
  # and exec_after_void_callbacks which is only available to
  # subclasses.
  class_methods do
    # Re-map void interface
    #
    # For example if you have a class that uses retired, and date_retired
    # instead of voided and voided_by, you can:
    #
    #    class Retirable
    #       include Voidable
    #
    #       remap_voidable_interface(voided: :retired, date_voided: :date_retired)
    #    end
    def remap_voidable_interface(voided: :voided, date_voided: :date_voided,
                                 void_reason: :void_reason,
                                 voided_by: :voided_by)
      @interface = {
        voided:,
        date_voided:,
        void_reason:,
        voided_by:
      }
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
    def after_void(*callbacks)
      _after_void_callbacks.push(*callbacks)
    end

    # private methods

    # Executes registered after_void callbacks
    def _exec_after_void_callbacks(instance, void_reason)
      _after_void_callbacks.each do |callback|
        instance.method(callback).call(void_reason)
      end
    end

    # Returns array of after_void callbacks
    def _after_void_callbacks
      @after_void_callbacks ||= []
    end

    def _voidable_field(field)
      remap_voidable_interface unless @interface # Initialise default interface
      @interface[field]
    end

    def _update_voidable_field(instance, field, value)
      # remap_voidable_interface unless @interface # Initialise default interface
      setter = "#{_voidable_field(field)}=".to_sym
      instance.method(setter).call(value)
    end
  end
end
