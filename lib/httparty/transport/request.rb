# frozen_string_literal: true

module HTTParty
  module Transport
    class Request
      attr_reader :method, :uri, :headers, :body, :body_stream, :options, :native

      def initialize(method:, uri:, headers:, body:, body_stream:, native: nil,
                     options: {})
        @method = method.to_s.upcase
        @uri = uri
        @headers = headers
        @body = body
        @body_stream = body_stream
        @options = options
        @native = native
      end

      def scheme
        uri.scheme
      end

      def host
        uri.host
      end

      def port
        uri.port
      end

      def path
        uri.path
      end

      def query
        uri.query
      end

      def request_uri
        uri.respond_to?(:request_uri) ? uri.request_uri : uri.path
      end
    end
  end
end
