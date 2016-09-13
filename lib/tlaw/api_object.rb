require 'forwardable'

module TLAW
  class APIObject
    class << self
      # @private
      attr_accessor :base_url, :path, :xml, :docs_link

      # @private
      def symbol
        # FIXME: the second part is necessary only for describes,
        #   and probably should not be here.
        @symbol || (name && "#{name}.new")
      end

      # @private
      CLASS_NAMES = {
        :[] => 'Element'
      }.freeze

      # @private
      def class_name
        # TODO:
        # * validate if it is classifiable
        # * provide additional option for non-default class name
        CLASS_NAMES[symbol] || Util.camelize(symbol.to_s)
      end

      # @private
      def description=(descr)
        @description = Util::Description.new(descr)
      end

      # @private
      def description
        return unless @description || @docs_link

        Util::Description.new(
          [@description, ("Docs: #{@docs_link}" if @docs_link)]
            .compact.join("\n\n")
        )
      end

      # @private
      def symbol=(sym)
        @symbol = sym
        @path ||= "/#{sym}"
      end

      def param_set
        @param_set ||= ParamSet.new
      end

      def response_processor
        @response_processor ||= ResponseProcessor.new
      end

      # @private
      def to_method_definition
        "#{symbol}(#{param_set.to_code})"
      end

      # @private
      def describe(definition = nil)
        Util::Description.new(
          ".#{definition || to_method_definition}" +
            (description ? "\n" + description.indent('  ') + "\n" : '') +
            (param_set.empty? ? '' : "\n" + param_set.describe.indent('  '))
        )
      end

      # @private
      def describe_short
        Util::Description.new(
          ".#{to_method_definition}" +
            (description ? "\n" + description_first_para.indent('  ') : '')
        )
      end

      # @private
      def define_method_on(host)
        file, line = method(:to_code).source_location
        # line + 1 is where real definition, theoretically, starts
        host.module_eval(to_code, file, line + 1)
      end

      private

      def description_first_para
        description.split("\n\n").first
      end
    end

    extend Forwardable

    def initialize(**parent_params)
      @parent_params = parent_params
    end

    private

    def object_class
      self.class
    end
  end
end
