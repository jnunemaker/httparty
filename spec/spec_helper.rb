require 'rubygems'
gem 'rspec'
require 'spec'
require File.join(File.dirname(__FILE__), '..', 'lib', 'httparty')

def file_fixture(filename)
  open(File.join(File.dirname(__FILE__), 'fixtures', "#{filename.to_s}")).read
end

def stub_http_response_with(filename)
  format = filename.split('.').last.intern
  data = file_fixture(filename)
  http = Net::HTTP.new('localhost', 80)
  
  response = Net::HTTPOK.new("1.1", 200, "Content for you")
  response.stub!(:body).and_return(data)
  http.stub!(:request).and_return(response)
  
  http_request = HTTParty::Request.new(Net::HTTP::Get, '')
  http_request.stub!(:get_response).and_return(response)
  http_request.stub!(:format).and_return(format)
  
  HTTParty::Request.should_receive(:new).and_return(http_request)
end