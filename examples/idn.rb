$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'addressable/uri'
require 'pp'

class Idn
    include HTTParty
    uri_adapter Addressable::URI
end

pp Idn.get("https://i❤️.ws/emojidomain/💎?format=json")