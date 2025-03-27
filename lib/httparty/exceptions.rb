# frozen_string_literal: true

module HTTParty
  COMMON_NETWORK_ERRORS = [
    EOFError,
    Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    Errno::EINVAL,
    Errno::ENETUNREACH,
    Errno::ENOTSOCK,
    Errno::EPIPE,
    Errno::ETIMEDOUT,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError,
    Net::ReadTimeout,
    OpenSSL::SSL::SSLError,
    SocketError,
    Timeout::Error # Also covers subclasses like Net::OpenTimeout
  ].freeze

  # @abstract Exceptions raised by HTTParty inherit from Error
  class Error < StandardError; end

  # @abstract Exceptions raised by HTTParty inherit from this because it is funny
  # and if you don't like fun you should be using a different library.
  class Foul < Error; end

  # Exception raised when you attempt to set a non-existent format
  class UnsupportedFormat < Foul; end

  # Exception raised when using a URI scheme other than HTTP or HTTPS
  class UnsupportedURIScheme < Foul; end

  # @abstract Exceptions which inherit from ResponseError contain the Net::HTTP
  # response object accessible via the {#response} method.
  class ResponseError < Foul
    # Returns the response of the last request
    # @return [Net::HTTPResponse] A subclass of Net::HTTPResponse, e.g.
    # Net::HTTPOK
    attr_reader :response

    # Instantiate an instance of ResponseError with a Net::HTTPResponse object
    # @param [Net::HTTPResponse]
    def initialize(response)
      @response = response
      super(response)
    end
  end

  # Exception that is raised when request has redirected too many times.
  # Calling {#response} returns the Net:HTTP response object.
  class RedirectionTooDeep < ResponseError; end

  # Exception that is raised when request redirects and location header is present more than once
  class DuplicateLocationHeader < ResponseError; end

  # Exception that is raised when common network errors occur.
  class NetworkError < Foul; end
end
