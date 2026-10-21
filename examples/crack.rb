require 'rubygems'
require 'crack'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

class Rep
  include HTTParty

  parser(
    proc do |body, format|
      Crack::XML.parse(body)
    end
  )
end

pp Rep.get('http://whoismyrepresentative.com/getall_mems.php?zip=46544')
pp Rep.get('http://whoismyrepresentative.com/getall_mems.php', query: { zip: 46544 })
