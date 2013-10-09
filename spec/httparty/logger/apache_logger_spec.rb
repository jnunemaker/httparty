require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe HTTParty::Logger::ApacheLogger do
  describe "#format" do
    it "formats a response in a style that resembles apache's access log" do
      request_time = Time.new.strftime("%Y-%m-%d %H:%M:%S %z")
      log_message = "[HTTParty] [#{request_time}] 302 \"GET http://my.domain.com/my_path\" - "

      request_double  = double(
        :http_method => Net::HTTP::Get,
        :path => "http://my.domain.com/my_path"
      )
      response_double = double(
        :code => 302,
        :[]   => nil
      )

      logger_double = double
      logger_double.should_receive(:info).with(log_message)

      subject = described_class.new(logger_double, :info)
      subject.current_time = request_time
      subject.format(request_double, response_double)
    end
  end
end
