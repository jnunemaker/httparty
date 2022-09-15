require 'spec_helper'

RSpec.describe HTTParty::Logger::ApacheFormatter do
  let(:subject) { described_class.new(logger_double, :info) }
  let(:logger_double) { double('Logger') }
  let(:request_double) { double('Request', http_method: Net::HTTP::Get, path: "http://my.domain.com/my_path") }
  let(:request_time) { Time.new.strftime("%Y-%m-%d %H:%M:%S %z") }

  before do
    expect(logger_double).to receive(:info).with(log_message)
  end

  describe "#format" do
    let(:log_message) { "[HTTParty] [#{request_time}] 302 \"GET http://my.domain.com/my_path\" - : 3" }

    it "formats a response in a style that resembles apache's access log" do
      response_double = double(
        code: 302,
        :[] => nil,
        response_time: 3
      )

      subject.format(request_double, response_double)
    end

    context 'when there is a parsed response' do
      let(:log_message) { "[HTTParty] [#{request_time}] 200 \"GET http://my.domain.com/my_path\" 512 : 5"}

      it "can handle the Content-Length header" do
        # Simulate a parsed response that is an array, where accessing a string key will raise an error. See Issue #299.
        response_double = double(
            code: 200,
            headers: { 'Content-Length' => 512 },
            response_time: 5
        )
        allow(response_double).to receive(:[]).with('Content-Length').and_raise(TypeError.new('no implicit conversion of String into Integer'))

        subject.format(request_double, response_double)
      end
    end
  end
end
