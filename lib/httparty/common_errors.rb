# frozen_string_literal: true

module HTTParty
  # Common net/http errors that can be wrapped by HTTParty::Foul
  module CommonErrors
    NETWORK_ERRORS = [
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
  end
end 