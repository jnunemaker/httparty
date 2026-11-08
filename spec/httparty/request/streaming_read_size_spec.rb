require 'spec_helper'

RSpec.describe HTTParty::Request::StreamingMultipartBody, 'bounded reads' do
  let(:boundary) { 'read-boundary' }
  let(:parts) { [['name', "Jöhn" * 50, false]] }

  [1, 3, 7, 64].each do |length|
    it "returns no more than #{length} bytes including fields and closing boundaries" do
      stream = described_class.new(parts, boundary)
      expected = stream.read
      stream.rewind
      chunks = []
      while (chunk = stream.read(length))
        expect(chunk.bytesize).to be <= length
        expect(chunk.encoding).to eq(Encoding::BINARY)
        chunks << chunk
      end
      expect(chunks.join).to eq(expected)
    end
  end

  it 'includes pending field bytes when switching from bounded to unbounded reads' do
    stream = described_class.new(parts, boundary)
    expected = stream.read
    stream.rewind
    prefix = stream.read(60)
    expect(prefix + stream.read).to eq(expected)
  end

  it 'discards pending bytes on rewind and reuses the supplied output buffer' do
    stream = described_class.new(parts, boundary)
    expected = stream.read
    stream.rewind
    stream.read(60)
    stream.rewind
    output = +'stale'
    expect(stream.read(3, output)).to equal(output)
    expect(output).to eq(expected.byteslice(0, 3))
    expect(output + stream.read).to eq(expected)
  end
end
