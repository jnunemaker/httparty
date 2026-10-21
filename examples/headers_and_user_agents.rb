# To send custom user agents to identify your application to a web service (or mask as a specific browser for testing), send "User-Agent" as a hash to headers as shown below.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

response = HTTParty.get('http://example.com', {
  headers: {"User-Agent" => "Httparty"},
  debug_output: STDOUT, # To show that User-Agent is Httparty
})
