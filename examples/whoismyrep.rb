dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'

class Rep
  include HTTParty
end

puts Rep.get('http://whoismyrepresentative.com/whoismyrep.php?zip=46544').inspect