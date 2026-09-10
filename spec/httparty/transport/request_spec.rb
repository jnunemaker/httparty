require 'spec_helper'

RSpec.describe HTTParty::Transport::Request do
  subject(:request) do
    described_class.new(
      method: :get,
      uri: URI('https://example.com:8443/path?q=value'),
      headers: { 'accept' => ['application/json'] },
      body: 'body',
      body_stream: nil,
      options: { timeout: 5 }
    )
  end

  it 'normalizes the method and exposes URI components' do
    expect(request.method).to eq('GET')
    expect(request.scheme).to eq('https')
    expect(request.host).to eq('example.com')
    expect(request.port).to eq(8443)
    expect(request.path).to eq('/path')
    expect(request.query).to eq('q=value')
    expect(request.request_uri).to eq('/path?q=value')
  end

  it 'exposes the prepared headers and body' do
    expect(request.headers).to eq('accept' => ['application/json'])
    expect(request.body).to eq('body')
    expect(request.body_stream).to be_nil
    expect(request.options).to eq(timeout: 5)
  end
end
