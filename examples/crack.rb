require 'rubygems'
require 'crack'

dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'

class Rep
  include HTTParty

  parser(
    Proc.new do |body, format|
      Crack::XML.parse(body)
    end
  )
end

pp Rep.get('http://whoismyrepresentative.com/whoismyrep.php?zip=46544')
pp Rep.get('http://whoismyrepresentative.com/whoismyrep.php', :query => {:zip => 46544})
