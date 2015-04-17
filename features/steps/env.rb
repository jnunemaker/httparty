require 'mongrel'
require './lib/httparty'
require 'rspec/expectations'
require 'aruba/cucumber'

def run_server(port)
  @host_and_port = "0.0.0.0:#{port}"
  @server = Mongrel::HttpServer.new("0.0.0.0", port)
  @server.run
  @request_options = {}
end

def new_port
  server = TCPServer.new('0.0.0.0', nil)
  port = server.addr[1]
ensure
  server.close
end

Before('~@command_line') do
  port = ENV["HTTPARTY_PORT"] || new_port
  run_server(port)
end

After do
  @server.stop if @server
end
