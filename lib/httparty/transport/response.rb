# frozen_string_literal: true

module HTTParty
  module Transport
    class Response
      NATIVE_BODY = Object.new.freeze

      attr_reader :code, :http_version, :reason_phrase, :native, :connection_info

      def self.from_native(response, connection_info: nil)
        new(
          code: response.respond_to?(:code) ? response.code : 0,
          headers: response.respond_to?(:to_hash) ? response.to_hash : {},
          body: NATIVE_BODY,
          http_version: response.respond_to?(:http_version) ? response.http_version : nil,
          reason_phrase: response.respond_to?(:message) ? response.message : nil,
          native: response,
          connection_info: connection_info
        )
      end

      def initialize(code:, headers:, body:, http_version: nil, reason_phrase: nil,
                     native: nil, connection_info: nil)
        @code = code.to_i
        @headers = normalize_headers(headers)
        @body = body
        @http_version = http_version
        @reason_phrase = reason_phrase
        @native = native
        @connection_info = connection_info
      end

      def body
        @body.equal?(NATIVE_BODY) ? native&.body : @body
      end

      def [](name)
        values = get_fields(name)
        return values.join(', ') if values

        native[name] if native && native.respond_to?(:[])
      end

      def get_fields(name)
        values = @headers[name.to_s.downcase]
        return values.dup if values

        native.get_fields(name) if native && native.respond_to?(:get_fields)
      end

      def key?(name)
        @headers.key?(name.to_s.downcase) ||
          (native && native.respond_to?(:key?) && native.key?(name))
      end

      def delete(name)
        native.delete(name) if native && native.respond_to?(:get_fields)
        @headers.delete(name.to_s.downcase)
      end

      def to_hash
        @headers.each_with_object({}) do |(name, values), copy|
          copy[name] = values.dup
        end
      end

      private

      private_constant :NATIVE_BODY

      def normalize_headers(headers)
        headers.each_with_object({}) do |(name, values), normalized|
          normalized[name.to_s.downcase] = Array(values).map(&:to_s)
        end
      end
    end

    class Chunk
      attr_reader :bytes, :response, :connection_info

      def initialize(bytes:, response:, connection_info: nil)
        @bytes = bytes
        @response = response
        @connection_info = connection_info
      end
    end
  end
end
