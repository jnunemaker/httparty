dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'

class Google
  include HTTParty
end

# google.com redirects to www.google.com so this is live test for redirection
pp Google.get('http://google.com')