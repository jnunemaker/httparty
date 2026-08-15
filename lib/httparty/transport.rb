# frozen_string_literal: true

module HTTParty
  module Transport
    class Error < HTTParty::Error; end
    class UnavailableError < Error; end
    class NetworkError < Error; end
    class UnsupportedOption < Error; end

    class << self
      def register(name, transport)
        transports[name.to_sym] = transport
      end

      def resolve(transport)
        return transport unless transport.is_a?(String) || transport.is_a?(Symbol)

        transports.fetch(transport.to_sym) do
          raise UnavailableError, "transport #{transport.inspect} is not registered"
        end
      end

      private

      def transports
        @transports ||= {}
      end
    end
  end
end

require 'httparty/transport/request'
require 'httparty/transport/response'
require 'httparty/transport/net_http'
require 'httparty/transport/curl'

HTTParty::Transport.register(:net_http, HTTParty::Transport::NetHttp)
HTTParty::Transport.register(:curl, HTTParty::Transport::Curl)
