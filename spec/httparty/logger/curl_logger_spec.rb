require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe HTTParty::Logger::CurlLogger do
  describe "#format" do
    it "formats a response in a style that resembles a -v curl" do
      request_time = Time.new.strftime("%Y-%m-%d %H:%M:%S.%L %z")

      logger_double = double
      logger_double.should_receive(:info).with(
          /\[HTTParty\] \[#{request_time}\] > GET http:\/\/localhost\n/)

      subject = described_class.new(logger_double, :info)
      subject.current_time = request_time

      stub_http_response_with("google.html")

      response = HTTParty::Request.new.perform
      subject.format(response.request, response)
    end
  end
end
