require 'spec_helper'
require 'tempfile'

RSpec.describe HTTParty::Request::Body do
  describe '#call' do
    let(:options) { {} }

    subject { described_class.new(params, **options).call }

    context 'when params is string' do
      let(:params) { 'name=Bob%20Jones' }

      it { is_expected.to eq params }
    end

    context 'when params is hash' do
      let(:params) { { people: ["Bob Jones", "Mike Smith"] } }
      let(:converted_params) { "people%5B%5D=Bob%20Jones&people%5B%5D=Mike%20Smith"}

      it { is_expected.to eq converted_params }

      context 'when params has file' do
        before do
          allow(HTTParty::Request::MultipartBoundary)
            .to receive(:generate).and_return("------------------------c772861a5109d5ef")
        end

        let(:file) { File.open('spec/fixtures/tiny.gif') }
        let(:params) do
          {
            user: {
              avatar: file,
              first_name: 'John',
              last_name: 'Doe',
              enabled: true
            }
          }
        end
        let(:expected_file_name) { 'tiny.gif' }
        let(:expected_file_contents) { "GIF89a\u0001\u0000\u0001\u0000\u0000\xFF\u0000,\u0000\u0000\u0000\u0000\u0001\u0000\u0001\u0000\u0000\u0002\u0000;" }
        let(:expected_content_type) { 'image/gif' }
        let(:multipart_params) do
          ("--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[avatar]\"; filename=\"#{expected_file_name}\"\r\n" \
          "Content-Type: #{expected_content_type}\r\n" \
          "\r\n" \
          "#{expected_file_contents}\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[first_name]\"\r\n" \
          "\r\n" \
          "John\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[last_name]\"\r\n" \
          "\r\n" \
          "Doe\r\n" \
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[enabled]\"\r\n" \
          "\r\n" \
          "true\r\n" \
          "--------------------------c772861a5109d5ef--\r\n").b
        end

        it { is_expected.to eq multipart_params }

        it { expect { subject }.not_to change { file.pos } }

        context 'when passing multipart as an option' do
          let(:options) { { force_multipart: true } }
          let(:params) do
            {
              user: {
                first_name: 'John',
                last_name: 'Doe',
                enabled: true
              }
            }
          end
          let(:multipart_params) do
            ("--------------------------c772861a5109d5ef\r\n" \
            "Content-Disposition: form-data; name=\"user[first_name]\"\r\n" \
            "\r\n" \
            "John\r\n" \
            "--------------------------c772861a5109d5ef\r\n" \
            "Content-Disposition: form-data; name=\"user[last_name]\"\r\n" \
            "\r\n" \
            "Doe\r\n" \
            "--------------------------c772861a5109d5ef\r\n" \
            "Content-Disposition: form-data; name=\"user[enabled]\"\r\n" \
            "\r\n" \
            "true\r\n" \
            "--------------------------c772861a5109d5ef--\r\n").b
          end

          it { is_expected.to eq multipart_params }

        end

        context 'file object responds to original_filename' do
          let(:some_temp_file) { Tempfile.new(['some_temp_file','.gif']) }
          let(:expected_file_name) { "some_temp_file.gif" }
          let(:expected_file_contents) { "Hello" }
          let(:file) { double(:mocked_action_dispatch, path: some_temp_file.path, original_filename: 'some_temp_file.gif', read: expected_file_contents) }

          before { some_temp_file.write('Hello') }

          it { is_expected.to eq multipart_params }
        end

        context 'when file name contains [ " \r \n ]' do
          let(:options) { { force_multipart: true } }
          let(:some_temp_file) { Tempfile.new(['basefile', '.txt']) }
          let(:file_content) { 'test' }
          let(:raw_filename) { "dummy=tampering.sh\"; \r\ndummy=a.txt" }
          let(:expected_file_name) { 'dummy=tampering.sh%22; %0D%0Adummy=a.txt' }
          let(:file) { double(:mocked_action_dispatch, path: some_temp_file.path, original_filename: raw_filename, read: file_content) }
          let(:params) do
            {
              user: {
                attachment_file: file,
                enabled: true
              }
            }
          end
          let(:multipart_params) do
            ("--------------------------c772861a5109d5ef\r\n" \
            "Content-Disposition: form-data; name=\"user[attachment_file]\"; filename=\"#{expected_file_name}\"\r\n" \
            "Content-Type: text/plain\r\n" \
            "\r\n" \
            "test\r\n" \
            "--------------------------c772861a5109d5ef\r\n" \
            "Content-Disposition: form-data; name=\"user[enabled]\"\r\n" \
            "\r\n" \
            "true\r\n" \
            "--------------------------c772861a5109d5ef--\r\n").b
          end

          it { is_expected.to eq multipart_params }

        end

        context 'when file is binary data and params contain non-ascii characters' do
          let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }
          let(:params) do
            {
              user: "Jöhn Döé",
              enabled: true,
              avatar: file,
            }
          end

          it 'does not raise encoding errors' do
            expect { subject }.not_to raise_error
          end

          it 'produces valid binary multipart body' do
            result = subject
            expect(result.encoding).to eq(Encoding::BINARY)
            expect(result).to include("Jöhn Döé".b)
          end

          it 'concatenates binary file data with UTF-8 text without corruption' do
            result = subject
            # Should contain both the UTF-8 user field and binary GIF data
            expect(result).to include('Content-Disposition: form-data; name="user"'.b)
            expect(result).to include("Jöhn Döé".b)
            expect(result).to include('Content-Disposition: form-data; name="avatar"'.b)
            expect(result).to include("GIF89a".b) # GIF file header
          end
        end
      end
    end
  end

  describe '#multipart?' do
    let(:force_multipart) { false }
    let(:file) { File.open('spec/fixtures/tiny.gif') }

    subject { described_class.new(params, force_multipart: force_multipart).multipart? }

    context 'when params does not respond to to_hash' do
      let(:params) { 'name=Bob%20Jones' }

      it { is_expected.to be false }
    end

    context 'when params responds to to_hash' do
      class HashLike
        def initialize(hash)
          @hash = hash
        end

        def to_hash
          @hash
        end
      end

      class ArrayLike
        def initialize(ary)
          @ary = ary
        end

        def to_ary
          @ary
        end
      end

      context 'when force_multipart is true' do
        let(:params) { { name: 'Bob Jones' } }
        let(:force_multipart) { true }

        it { is_expected.to be true }
      end

      context 'when it does not contain a file' do
        let(:hash_like_param) { HashLike.new(first: 'Bob', last: ArrayLike.new(['Jones'])) }
        let(:params) { { name: ArrayLike.new([hash_like_param]) } }

        it { is_expected.to eq false }
      end

      context 'when it contains file' do
        let(:hash_like_param) { HashLike.new(first: 'Bob', last: 'Jones', file: ArrayLike.new([file])) }
        let(:params) { { name: ArrayLike.new([hash_like_param]) } }

        it { is_expected.to be true }
      end
    end
  end

  describe '#streaming?' do
    let(:file) { File.open('spec/fixtures/tiny.gif') }

    after { file.close }

    context 'when params contains a file' do
      let(:params) { { avatar: file } }
      subject { described_class.new(params) }

      it { expect(subject.streaming?).to be true }
    end

    context 'when force_multipart but no file' do
      let(:params) { { name: 'John' } }
      subject { described_class.new(params, force_multipart: true) }

      it { expect(subject.streaming?).to be false }
    end

    context 'when params is a string' do
      let(:params) { 'name=John' }
      subject { described_class.new(params) }

      it { expect(subject.streaming?).to be false }
    end
  end

  describe '#to_stream' do
    let(:file) { File.open('spec/fixtures/tiny.gif', 'rb') }

    after { file.close }

    context 'when streaming is possible' do
      let(:params) { { avatar: file } }
      subject { described_class.new(params) }

      it 'returns a StreamingMultipartBody' do
        expect(subject.to_stream).to be_a(HTTParty::Request::StreamingMultipartBody)
      end

      it 'produces equivalent content to call' do
        allow(HTTParty::Request::MultipartBoundary).to receive(:generate).and_return('test-boundary')

        stream = subject.to_stream
        file.rewind
        streamed_content = stream.read

        file.rewind
        body = described_class.new(params)
        allow(HTTParty::Request::MultipartBoundary).to receive(:generate).and_return('test-boundary')
        regular_content = body.call

        expect(streamed_content).to eq(regular_content)
      end
    end

    context 'when streaming is not possible' do
      let(:params) { { name: 'John' } }
      subject { described_class.new(params, force_multipart: true) }

      it 'returns nil' do
        expect(subject.to_stream).to be_nil
      end
    end
  end
end
