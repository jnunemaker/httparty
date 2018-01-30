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
        let(:params) do
          {
            user: {
              avatar: File.open('spec/fixtures/tiny.gif'),
              first_name: 'John',
              last_name: 'Doe'
            }
          }
        end
        let(:multipart_params) do
          "--------------------------c772861a5109d5ef\n" \
          "Content-Disposition: form-data; name='user[avatar]'; filename='tiny.gif'\n" \
          "Content-Type: application/octet-stream\n" \
          "\n" \
          "GIF89a\u0001\u0000\u0001\u0000\u0000\xFF\u0000,\u0000\u0000\u0000\u0000\u0001\u0000\u0001\u0000\u0000\u0002\u0000;\n" \
          "--------------------------c772861a5109d5ef\n" \
          "Content-Disposition: form-data; name='user[first_name]'\n" \
          "\n" \
          "John\n" \
          "--------------------------c772861a5109d5ef\n" \
          "Content-Disposition: form-data; name='user[last_name]'\n" \
          "\n" \
          "Doe\n" \
          "--------------------------c772861a5109d5ef--\n"
        end

        it { is_expected.to eq multipart_params }
      end
    end
  end
end
