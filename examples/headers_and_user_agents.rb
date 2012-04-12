# To send custom user agents to identify your application to a web service (or mask as a specific browser for testing), send "User-Agent" as a hash to headers as shown below.

require 'httparty'

APPLICATION_NAME = "Httparty" 
response = HTTParty.get('http://example.com', :headers => {"User-Agent" => APPLICATION_NAME})
