require 'forwardable'
require 'inflecto'
require 'contextualizer'
require 'pathway/version'
require 'pathway/result'

module Pathway
  class Operation
    def self.plugin(name, *args)
      require "pathway/plugins/#{Inflecto.underscore(name)}" if name.is_a?(Symbol)

      plugin = name.is_a?(Module) ? name : Plugins.const_get(Inflecto.camelize(name))

      self.extend plugin::ClassMethods if plugin.const_defined? :ClassMethods
      self.include plugin::InstanceMethods if plugin.const_defined? :InstanceMethods
      self::DSL.include plugin::DSLMethods if plugin.const_defined? :DSLMethods

      plugin.apply(self, *args) if plugin.respond_to?(:apply)
    end

    def self.inherited(subclass)
      super
      subclass.const_set :DSL, Class.new(self::DSL)
    end

    class DSL
    end
  end

  class Error < StandardError
    attr_reader :type, :message, :details
    singleton_class.send :attr_accessor, :default_messages

    @default_messages = {}

    alias :error_type :type
    alias :error_message :message
    alias :errors :details

    def initialize(type:, message: nil, details: nil)
      @type    = type.to_sym
      @message = message || default_message_for(type)
      @details = details || {}
    end

    private

    def default_message_for(type)
      self.class.default_messages[type] || Inflecto.humanize(type)
    end
  end

  class State
    extend Forwardable

    def initialize(operation, values = {})
      @hash = operation.context.merge(values)
      @result_key = operation.result_key
    end

    delegate %i([] []= fetch store include?) => :@hash

    def update(kargs)
      @hash.update(kargs)
      self
    end

    def result
      @hash[@result_key]
    end

    def to_hash
      @hash
    end

    alias :to_h :to_hash
  end

  module Plugins
    module Base
      module ClassMethods
        attr_accessor :result_key

        def process(&bl)
          dsl = self::DSL
          define_method(:call) do |input|
            dsl.new(self, input).run(&bl).then(&:result)
          end
        end

        alias :result_at :result_key=

        def inherited(subclass)
          super
          subclass.result_key = result_key
        end
      end

      module InstanceMethods
        extend Forwardable

        def result_key
          self.class.result_key
        end

        def call(*)
          fail "must implement at subclass"
        end

        delegate %i[result success failure] => Result

        alias :wrap :result

        def error(type, message: nil, details: nil)
          failure Error.new(type: type, message: message, details: details)
        end

        def wrap_if_present(value, type: :not_found, message: nil, details: [])
          value.nil? ? error(type, message: message, details: details) : success(value)
        end
      end

      def self.apply(klass)
        klass.extend Contextualizer
        klass.result_key = :value
      end

      module DSLMethods
        def initialize(operation, input)
          @result = wrap(State.new(operation, input: input))
          @operation = operation
        end

        def run(&bl)
          instance_eval(&bl)
          @result
        end

        # Execute step and preserve the former state
        def step(callable, *args)
          bl = _callable(callable)

          @result = @result.tee { |state| bl.call(state, *args) }
        end

        # Execute step and modify the former state setting the key
        def set(callable, *args, to: @operation.result_key)
          bl = _callable(callable)

          @result = @result.then do |state|
            wrap(bl.call(state, *args))
              .then { |value| state.update(to => value) }
          end
        end

        # Execute step and replace the current state completely
        def map(callable)
          bl = _callable(callable)
          @result = @result.then(bl)
        end

        def sequence(with_seq, &bl)
          @result.then do |state|
            seq = -> { @result = dup.run(&bl) }
            _callable(with_seq).call(seq, state)
          end
        end

        def guard(cond, &bl)
          cond = _callable(cond)
          sequence(-> seq, state {
            seq.call if cond.call(state)
          }, &bl)
        end

        private

        def wrap(obj)
          Result.result(obj)
        end

        def _callable(callable)
          case callable
          when Proc
            -> *args { @operation.instance_exec(*args, &callable) }
          when Symbol
            -> *args { @operation.send(callable, *args) }
          else
            callable
          end
        end
      end
    end
  end

  Operation.plugin Plugins::Base
end
