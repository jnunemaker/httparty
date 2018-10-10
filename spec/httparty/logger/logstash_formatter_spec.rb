require 'spec_helper'

RSpec.describe HTTParty::Logger::LogstashFormatter do
  let(:severity) { :info }
  let(:http_method) { 'GET' }
  let(:path) { 'http://my.domain.com/my_path' }
  let(:logger_double) { double('Logger') }
  let(:request_double) { double('Request', http_method: Net::HTTP::Get, path: "#{path}") }
  let(:request_time) { Time.new.strftime("%Y-%m-%d %H:%M:%S %z") }
  let(:log_message) do
    {
      '@timestamp' => request_time,
      '@version' => 1,
      'content_length' => content_length || '-',
      'http_method' => http_method,
      'message' => message,
      'path' => path,
      'response_code' => response_code,
      'severity' => severity,
      'tags' => ['HTTParty'],
    }.to_json
  end

  subject { described_class.new(logger_double, severity) }

  before do
    expect(logger_double).to receive(:info).with(log_message)
  end

  describe "#format" do
    let(:response_code) { 302 }
    let(:content_length) { '-' }
    let(:message) { "[HTTParty] #{response_code} \"#{http_method} #{path}\" #{content_length} " }

    it "formats a response to be compatible with Logstash" do
      response_double = double(
        code: response_code,
        :[] => nil
      )

      subject.format(request_double, response_double)
    end
  end
end
