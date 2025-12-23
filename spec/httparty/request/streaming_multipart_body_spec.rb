require 'spec_helper'
require 'tempfile'

RSpec.describe HTTParty::Request::StreamingMultipartBody do
  let(:boundary) { '------------------------c772861a5109d5ef' }

  describe '#read' do
    context 'with a simple file' do
      let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
      let(:parts) { [['avatar', file, true]] }
      subject { described_class.new(parts, boundary) }

      after { file.close }

      it 'streams the complete multipart body' do
        result = subject.read
        expect(result.encoding).to eq(Encoding::BINARY)
        expect(result).to include("--#{boundary}")
        expect(result).to include('Content-Disposition: form-data; name="avatar"')
        expect(result).to include('filename="tiny.gif"')
        expect(result).to include('Content-Type: image/gif')
        expect(result).to include("GIF89a") # GIF file header
        expect(result).to end_with("--#{boundary}--\r\n")
      end

      it 'returns same content as non-streaming body' do
        # Create equivalent Body for comparison
        body = HTTParty::Request::Body.new({ avatar: File.open('spec/fixtures/tiny.gif', 'rb') })
        allow(HTTParty::Request::MultipartBoundary).to receive(:generate).and_return(boundary)

        streaming_result = subject.read
        non_streaming_result = body.call

        expect(streaming_result).to eq(non_streaming_result)
      end
    end

    context 'with mixed file and text fields' do
      let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
      let(:parts) do
        [
          ['user[avatar]', file, true],
          ['user[name]', 'John Doe', false],
          ['user[active]', 'true', false]
        ]
      end
      subject { described_class.new(parts, boundary) }

      after { file.close }

      it 'streams all parts correctly' do
        result = subject.read
        expect(result).to include('name="user[avatar]"')
        expect(result).to include('name="user[name]"')
        expect(result).to include('John Doe')
        expect(result).to include('name="user[active]"')
        expect(result).to include('true')
      end
    end

    context 'reading in chunks' do
      let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
      let(:parts) { [['avatar', file, true]] }
      subject { described_class.new(parts, boundary) }

      after { file.close }

      it 'reads correctly in small chunks' do
        chunks = []
        while (chunk = subject.read(10))
          chunks << chunk
        end
        full_result = chunks.join

        subject.rewind
        single_read = subject.read

        expect(full_result).to eq(single_read)
      end

      it 'returns nil when exhausted' do
        subject.read # Read all
        expect(subject.read).to be_nil
      end
    end
  end

  describe '#size' do
    let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
    let(:parts) { [['avatar', file, true]] }
    subject { described_class.new(parts, boundary) }

    after { file.close }

    it 'returns the correct total size' do
      size = subject.size
      content = subject.read
      expect(size).to eq(content.bytesize)
    end
  end

  describe '#rewind' do
    let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
    let(:parts) { [['avatar', file, true]] }
    subject { described_class.new(parts, boundary) }

    after { file.close }

    it 'allows re-reading the stream' do
      first_read = subject.read
      subject.rewind
      second_read = subject.read
      expect(first_read).to eq(second_read)
    end
  end

  describe 'memory efficiency' do
    it 'does not load entire file into memory at once' do
      # Create a larger temp file
      tempfile = Tempfile.new(['large', '.bin'])
      tempfile.write('x' * (1024 * 1024)) # 1 MB
      tempfile.rewind

      parts = [['file', tempfile, true]]
      stream = described_class.new(parts, boundary)

      # Read in small chunks - this should work without allocating 1MB at once
      chunks_read = 0
      while stream.read(1024)
        chunks_read += 1
      end

      expect(chunks_read).to be > 100 # Should have read many chunks
      tempfile.close
      tempfile.unlink
    end
  end
end
