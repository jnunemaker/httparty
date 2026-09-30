require 'spec_helper'

RSpec.describe HTTParty::Transport::Response do
  subject(:response) do
    described_class.new(
      code: '200',
      headers: {
        'Content-Type' => 'text/plain',
        'Set-Cookie' => ['first=1', 'second=2']
      },
      body: 'hello',
      http_version: '2'
    )
  end

  it 'normalizes status and headers' do
    expect(response.code).to eq(200)
    expect(response['content-type']).to eq('text/plain')
    expect(response.get_fields('SET-COOKIE')).to eq(['first=1', 'second=2'])
    expect(response).to be_key('Content-Type')
  end

  it 'returns defensive header copies' do
    headers = response.to_hash
    headers['set-cookie'] << 'third=3'

    expect(response.get_fields('set-cookie')).to eq(['first=1', 'second=2'])
  end

  it 'deletes headers case-insensitively' do
    response.delete('CONTENT-TYPE')

    expect(response).not_to be_key('content-type')
  end

  it 'uses an explicit body when a native response is also present' do
    native = double('native response', body: 'native')
    response = described_class.new(code: 200, headers: {}, body: 'normalized', native: native)

    expect(response.body).to eq('normalized')
  end
end
