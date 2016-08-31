require 'faraday'
require 'addressable/template'
require 'forwardable'

module TLAW
  class Endpoint
    class << self
      attr_accessor :base_url, :path, :symbol, :description

      def param_set
        @param_set ||= ParamSet.new
      end

      def to_code
        "def #{symbol}(#{param_set.to_code})\n" +
        "  param = initial_params.merge({#{param_set.names.map { |n| "#{n}: #{n}" }.join(', ')}})\n" +
        "  endpoints[:#{symbol}].call(**param)\n" +
        "end"
      end

      def response_processor
        @response_processor ||= ResponseProcessor.new
      end

      def inspect
        "#<#{name || '(unnamed endpoint class)'}: call-sequence: #{symbol}(#{param_set.to_code}); docs: .describe>"
      end

      def describe
        Util::Description.new(
          "Synopsys: #{symbol}(#{param_set.to_code})\n" +
            description.to_s.gsub(/(\A|\n)/, '\1  ') + "\n" +
            param_set.describe.indent('  ')
        )
      end
    end

    attr_reader :url_template

    def initialize
      @client = Faraday.new
      @url_template = construct_template
    end

    def call(**params)
      url = construct_url(**params)

      @client.get(construct_url(**params))
        .tap { |response| guard_errors!(response) }
        .derp { |response| JSON.parse(response.body) }
        .derp { |response| self.class.response_processor.process(response) }
    rescue API::Error
      raise
    rescue => e
      raise unless url
      fail API::Error, "#{e.class} at #{url}: #{e.message}"
    end

    extend Forwardable

    def_delegators :self_class, :inspect, :describe

    private

    def self_class
      self.class
    end

    def guard_errors!(response)
      return response if (200...400).include?(response.status)

      body = JSON.parse(response.body) rescue nil
      message = body && (body['message'] || body['error'])

      if message
        fail API::Error, "HTTP #{response.status} at #{response.env[:url]}: #{message}"
      else
        fail API::Error, "HTTP #{response.status} at #{response.env[:url]}"
      end
    end

    def construct_template
      t = Addressable::Template.new(self.class.base_url)
      query_params = self.class.param_set.all_params.reject { |k, v| t.keys.include?(k.to_s) }

      tpl = if query_params.empty?
          self.class.base_url
        else
          joiner = self.class.base_url.include?('?') ? '&' : '?'

          self.class.base_url + '{' + joiner + query_params.keys.join(',') + '}'
        end
      Addressable::Template.new(tpl)
    end

    def construct_url(**params)
      url_params = self.class.param_set.process(**params)
      @url_template.expand(url_params).to_s
    end
  end
end
