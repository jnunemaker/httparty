require 'spec_helper'

RSpec.describe HTTParty::Response, 'falsey parsed values' do
  [false, nil].each do |value|
    it "parses #{value.inspect} only once" do
      calls = 0
      raw = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(raw).to receive(:body).and_return(value.to_json)
      request = HTTParty::Request.new(Net::HTTP::Get, '/')
      response = described_class.new(request, raw, -> { calls += 1; value })

      3.times { expect(response.parsed_response).to equal(value) }
      expect(calls).to eq(1)
    end
  end

  it 'still retries parsing after a parser raises' do
    calls = 0
    raw = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(raw).to receive(:body).and_return('null')
    request = HTTParty::Request.new(Net::HTTP::Get, '/')
    response = described_class.new(request, raw, lambda {
      calls += 1
      raise 'parse failed' if calls == 1
      nil
    })

    expect { response.parsed_response }.to raise_error('parse failed')
    expect(response.parsed_response).to be_nil
    expect(response.parsed_response).to be_nil
    expect(calls).to eq(2)
  end
end
