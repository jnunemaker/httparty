$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'

peer_cert = nil
HTTParty.get("https://www.example.com") do |fragment|
  peer_cert ||= fragment.connection.peer_cert
end

puts "The server's certificate expires #{peer_cert.not_after}"
