# frozen_string_literal: true

module HTTParty
  module Transport
    class NetHttp
      REQUEST_CLASSES = {
        'GET' => Net::HTTP::Get,
        'POST' => Net::HTTP::Post,
        'PATCH' => Net::HTTP::Patch,
        'PUT' => Net::HTTP::Put,
        'DELETE' => Net::HTTP::Delete,
        'HEAD' => Net::HTTP::Head,
        'OPTIONS' => Net::HTTP::Options,
        'MOVE' => Net::HTTP::Move,
        'COPY' => Net::HTTP::Copy,
        'MKCOL' => Net::HTTP::Mkcol,
        'LOCK' => Net::HTTP::Lock,
        'UNLOCK' => Net::HTTP::Unlock
      }.freeze

      def initialize(options = {})
        return if options.empty?

        raise UnsupportedOption, "net_http transport does not support: #{options.keys.join(', ')}"
      end

      def perform(request)
        connection_adapter = request.options.fetch(:connection_adapter)
        connection = connection_adapter.call(request.uri, request.options)
        transport_response = nil
        native_request = request.native || build_request(request)

        native_response = if block_given?
                            connection.request(native_request) do |response|
                              transport_response = Response.from_native(response, connection_info: connection)
                              response.read_body do |bytes|
                                yield Chunk.new(
                                  bytes: bytes,
                                  response: transport_response,
                                  connection_info: connection
                                )
                              end
                            end
                          else
                            connection.request(native_request)
                          end

        transport_response || Response.from_native(native_response, connection_info: connection)
      end

      def close
      end

      private

      def build_request(request)
        request_class = REQUEST_CLASSES.fetch(request.method) do
          raise UnsupportedOption, "Net::HTTP does not support the #{request.method} method"
        end
        native_request = request_class.new(request.request_uri)
        request.headers.each do |name, values|
          native_request.delete(name)
          Array(values).each { |value| native_request.add_field(name, value) }
        end
        native_request.body = request.body if request.body
        native_request.body_stream = request.body_stream if request.body_stream
        native_request
      end
    end
  end
end
