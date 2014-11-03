require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe HTTParty::Logger::SimpleLogger do
  describe "#format" do
    it "logs essential information about request and response" do
      logger = double
      logger.should_receive(:info).with(/GET http:\/\/localhost - 200 - RESPONSE/)

      subject = described_class.new(logger, :info)
      stub_http_response_with("response.txt")
      response = HTTParty::Request.new.perform
      subject.format(response.request, response)
    end
  end
end
