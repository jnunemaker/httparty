# frozen_string_literal: true

RSpec.shared_examples 'an HTTParty transport' do
  it 'returns a normalized response' do
    response = perform_request

    expect(response).to be_a(HTTParty::Transport::Response)
    expect(response.code).to eq(200)
    expect(response['Content-Type']).to eq('text/plain')
    expect(response.body).to eq('hello')
  end

  it 'streams response chunks in order' do
    chunks = []
    response = perform_streaming_request.call { |chunk| chunks << chunk }

    expect(chunks.map(&:bytes)).to eq(%w[hel lo])
    expect(chunks.map(&:response).uniq).to eq([response])
    expect(chunks.map(&:connection_info).uniq).to eq([response.connection_info])
  end

  it 'can be closed repeatedly' do
    expect { 2.times { transport.close } }.not_to raise_error
  end
end
