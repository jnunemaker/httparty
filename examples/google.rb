$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

class Google
  include HTTParty
  format :html
end

# google.com redirects to www.google.com so this is live test for redirection
pp Google.get('http://google.com')

puts '', '*' * 70, ''

# check that ssl is requesting right
pp Google.get('https://www.google.com')
