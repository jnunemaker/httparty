require 'spec_helper'

RSpec.describe HTTParty::Decompressor do
  describe '.SupportedEncodings' do
    it 'returns a hash' do
      expect(HTTParty::Decompressor::SupportedEncodings).to be_instance_of(Hash)
    end
  end

  describe '#decompress' do
    let(:body) { 'body' }
    let(:encoding) { 'none' }
    let(:decompressor) { described_class.new(body, encoding) }
    subject { decompressor.decompress }

    shared_examples 'returns nil' do
      it { expect(subject).to be_nil }
    end

    shared_examples 'returns the body' do
      it { expect(subject).to eq 'body' }
    end

    context 'when body is nil' do
      let(:body) { nil }
      it_behaves_like 'returns nil'
    end

    context 'when body is blank' do
      let(:body) { ' ' }
      it { expect(subject).to eq ' ' }
    end

    context 'when encoding is nil' do
      let(:encoding) { nil }
      it_behaves_like 'returns the body'
    end

    context 'when encoding is blank' do
      let(:encoding) { ' ' }
      it_behaves_like 'returns the body'
    end

    context 'when encoding is "none"' do
      let(:encoding) { 'none' }
      it_behaves_like 'returns the body'
    end

    context 'when encoding is "identity"' do
      let(:encoding) { 'identity' }
      it_behaves_like 'returns the body'
    end

    context 'when encoding is unsupported' do
      let(:encoding) { 'invalid' }
      it_behaves_like 'returns nil'
    end

    context 'when encoding is "br"' do
      let(:encoding) { 'br' }

      context 'when brotli gem not included' do
        it_behaves_like 'returns nil'
      end

      context 'when brotli included' do
        before do
          dbl = double('Brotli')
          expect(dbl).to receive(:inflate).with('body').and_return('foobar')
          stub_const('Brotli', dbl)
        end

        it { expect(subject).to eq 'foobar' }
      end

      context 'when brotli raises error' do
        before do
          dbl = double('brotli')
          expect(dbl).to receive(:inflate).with('body') { raise RuntimeError.new('brotli error') }
          stub_const('Brotli', dbl)
        end

        it { expect(subject).to eq nil }
      end
    end

    context 'when encoding is "compress"' do
      let(:encoding) { 'compress' }

      context 'when LZW gem not included' do
        it_behaves_like 'returns nil'
      end

      context 'when ruby-lzws included' do
        before do
          dbl = double('lzws')
          expect(dbl).to receive(:decompress).with('body').and_return('foobar')
          stub_const('LZWS::String', dbl)
        end

        it { expect(subject).to eq 'foobar' }
      end

      context 'when ruby-lzws raises error' do
        before do
          dbl = double('lzws')
          expect(dbl).to receive(:decompress).with('body') { raise RuntimeError.new('brotli error') }
          stub_const('LZWS::String', dbl)
        end

        it { expect(subject).to eq nil }
      end

      context 'when compress-lzw included' do
        before do
          dbl2 = double('lzw2')
          dbl = double('lzw1', new: dbl2)
          expect(dbl2).to receive(:decompress).with('body').and_return('foobar')
          stub_const('LZW::Simple', dbl)
        end

        it { expect(subject).to eq 'foobar' }
      end

      context 'when compress-lzw raises error' do
        before do
          dbl2 = double('lzw2')
          dbl = double('lzw1', new: dbl2)
          expect(dbl2).to receive(:decompress).with('body') { raise RuntimeError.new('brotli error') }
          stub_const('LZW::Simple', dbl)
        end
      end
    end

    context 'when encoding is "zstd"' do
      let(:encoding) { 'zstd' }

      context 'when zstd-ruby gem not included' do
        it_behaves_like 'returns nil'
      end

      context 'when zstd-ruby included' do
        before do
          dbl = double('Zstd')
          expect(dbl).to receive(:decompress).with('body').and_return('foobar')
          stub_const('Zstd', dbl)
        end

        it { expect(subject).to eq 'foobar' }
      end

      context 'when zstd raises error' do
        before do
          dbl = double('Zstd')
          expect(dbl).to receive(:decompress).with('body') { raise RuntimeError.new('zstd error') }
          stub_const('Zstd', dbl)
        end

        it { expect(subject).to eq nil }
      end
    end
  end
end
