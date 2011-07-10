$:.push File.expand_path("../lib", __FILE__)

require 'httparty'
require 'fakeweb'

def file_fixture(filename)
  open(File.join(File.dirname(__FILE__), 'fixtures', "#{filename.to_s}")).read
end

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

RSpec.configure do |config|
  config.include HTTParty::StubResponse
  config.include HTTParty::SSLTestHelper
  
  config.before(:suite) do
    FakeWeb.allow_net_connect = false
  end
  
  config.after(:suite) do
    FakeWeb.allow_net_connect = true
  end
end
