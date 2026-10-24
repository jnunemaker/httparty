$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

# postman-echo.com accepts the username "postman" with the password "password".
class PostmanEcho
  include HTTParty
  base_uri 'https://postman-echo.com'
  basic_auth 'postman', 'password' # sent with every request from this class
end

pp PostmanEcho.get('/basic-auth').parsed_response # => {"authenticated"=>true}

# Or pass the credentials with a single request.
response = HTTParty.get(
  'https://postman-echo.com/basic-auth',
  basic_auth: { username: 'postman', password: 'wrong' }
)
puts response.code # => 401
