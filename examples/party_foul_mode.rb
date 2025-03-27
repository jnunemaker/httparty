require 'httparty'

class APIClient
  include HTTParty
  base_uri 'api.example.com'

  def self.fetch_user(id)
    begin
      get("/users/#{id}", foul: true)
    rescue HTTParty::NetworkError => e
      handle_network_error(e)
    rescue HTTParty::ResponseError => e
      handle_api_error(e)
    end
  end

  private

  def self.handle_network_error(error)
    case error.cause
    when Errno::ECONNREFUSED
      {
        error: :server_down,
        message: "The API server appears to be down",
        details: error.message
      }
    when Net::OpenTimeout, Timeout::Error
      {
        error: :timeout,
        message: "The request timed out",
        details: error.message
      }
    when SocketError
      {
        error: :network_error,
        message: "Could not connect to the API server",
        details: error.message
      }
    when OpenSSL::SSL::SSLError
      {
        error: :ssl_error,
        message: "SSL certificate verification failed",
        details: error.message
      }
    else
      {
        error: :unknown_network_error,
        message: "An unexpected network error occurred",
        details: error.message
      }
    end
  end

  def self.handle_api_error(error)
    {
      error: :api_error,
      message: "API returned error #{error.response.code}",
      details: error.response.body
    }
  end
end

# Example usage:

# 1. When server is down
result = APIClient.fetch_user(123)
puts "Server down example:"
puts result.inspect
puts

# 2. When request times out
result = APIClient.fetch_user(456)
puts "Timeout example:"
puts result.inspect
puts

# 3. When SSL error occurs
result = APIClient.fetch_user(789)
puts "SSL error example:"
puts result.inspect
puts

# 4. Simple example without a wrapper class
begin
  HTTParty.get('https://api.example.com/users', foul: true)
rescue HTTParty::Foul => e
  puts "Direct usage example:"
  puts "Error type: #{e.cause.class}"
  puts "Error message: #{e.message}"
end
