$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'

# debug_output prints each request and response, headers included, so you can
# see exactly what goes over the wire. It defaults to $stderr. The output
# includes credentials such as the Authorization header, so keep it out of
# production logs.
class PostmanEcho
  include HTTParty
  base_uri 'https://postman-echo.com'
  debug_output $stdout
end

PostmanEcho.get('/get', query: { party: 'hard' })

# Or turn it on for a single request.
HTTParty.get('https://postman-echo.com/get', debug_output: $stdout)
