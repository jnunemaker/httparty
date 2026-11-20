require 'spec_helper'
require 'pp'

RSpec.describe HTTParty::Response, 'with a body that fails to parse' do
  let(:raw) do
    Net::HTTPBadGateway.new('1.1', '502', 'Bad Gateway').tap do |raw|
      raw['content-type'] = 'application/json'
      allow(raw).to receive(:body).and_return('<html>Bad Gateway</html>')
    end
  end
  let(:request) { HTTParty::Request.new(Net::HTTP::Get, 'http://example.com/', format: :json) }
  let(:response) { described_class.new(request, raw, -> { HTTParty::Parser.call(raw.body, :json) }) }

  it 'inspects without raising and shows the error and the body' do
    inspect = response.inspect

    expect(inspect).to include('parsed_response=#<JSON::ParserError')
    expect(inspect).to include('body="<html>Bad Gateway</html>"')
    expect(inspect).to include('@response=#<Net::HTTPBadGateway 502 Bad Gateway')
  end

  it 'escapes control characters from the parse error message' do
    allow(raw).to receive(:body).and_return("\e[2J")

    expect(response.inspect).not_to include("\e")
  end

  it 'pretty prints without raising' do
    expect(response.pretty_inspect).to include('parsed_response=#<JSON::ParserError')
  end

  it 'still raises from parsed_response' do
    expect { response.parsed_response }.to raise_error(JSON::ParserError)
  end
end
