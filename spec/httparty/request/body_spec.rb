require_relative '../../spec_helper'

RSpec.describe HTTParty::Request::Body do
  describe '#call' do
    subject { described_class.new(params).call }

    context 'when params is string' do
      let(:params) { 'name=Bob%20Jones' }

      it { is_expected.to eq params }
    end

    context 'when params is hash' do
      let(:params) { { people: ["Bob Jones", "Mike Smith"] } }
      let(:converted_params) { "people[]=Bob%20Jones&people[]=Mike%20Smith"}

      it { is_expected.to eq converted_params }

      context 'when params has file' do
        before do
          allow(HTTParty::Request::MultipartBoundary).
            to receive(:generate).and_return("------------------------c772861a5109d5ef")
        end

        let(:params) do
          {
            user: {
              avatar: File.open('spec/fixtures/tiny.gif'),
              first_name: 'John',
              last_name: 'Doe',
              enabled: true
            }
          }
        end
        let(:multipart_params) do
          "--------------------------c772861a5109d5ef\r\n" \
          "Content-Disposition: form-data; name=\"user[avatar]\"; filename=\"tiny.gif\"\r\n" \
          "Content-Type: application/octet-stream\r\n" \
          "\r\n" \
          "GIF89a\u0001\u0000\u0001\u0000\u0000\xFF\u0000,\u0000\u0000\u0000\u0000\u0001\u0000\u0001\u0000\u0000\u0002\u0000;\r\n" \
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
          "--------------------------c772861a5109d5ef--\r\n"
        end

        it { is_expected.to eq multipart_params }
      end
    end
  end
end
