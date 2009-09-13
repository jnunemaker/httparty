require 'mongrel'
require 'activesupport'
require 'lib/httparty'
require 'spec/expectations'

Before do
  port = ENV["HTTPARTY_PORT"] || 31981
  @host_and_port = "0.0.0.0:#{port}"
  @server = Mongrel::HttpServer.new("0.0.0.0", port)
  @server.run
  @request_options = {}
end

After do
  @server.stop
end
