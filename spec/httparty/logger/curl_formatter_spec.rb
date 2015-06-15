require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

RSpec.describe HTTParty::Logger::CurlFormatter do
  describe "#format" do
    it "formats a response in a style that resembles a -v curl" do
      logger_double = double
      expect(logger_double).to receive(:info).with(
          /\[HTTParty\] \[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\ [+-]\d{4}\] > GET http:\/\/localhost/)

      subject = described_class.new(logger_double, :info)

      stub_http_response_with("google.html")

      response = HTTParty::Request.new.perform
      subject.format(response.request, response)
    end
  end
end
