require 'spec_helper'

RSpec.describe HTTParty::Transport do
  class ExampleTransport
  end

  it 'resolves a registered transport' do
    described_class.register(:example, ExampleTransport)

    expect(described_class.resolve(:example)).to eq(ExampleTransport)
    expect(described_class.resolve('example')).to eq(ExampleTransport)
  end

  it 'passes transport classes through unchanged' do
    expect(described_class.resolve(ExampleTransport)).to eq(ExampleTransport)
  end

  it 'raises an actionable error for an unavailable transport' do
    expect do
      described_class.resolve(:missing)
    end.to raise_error(
      HTTParty::Transport::UnavailableError,
      'transport :missing is not registered'
    )
  end
end
