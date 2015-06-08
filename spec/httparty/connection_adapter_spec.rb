require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe HTTParty::ConnectionAdapter do
  describe "initialization" do
    let(:uri) { URI 'http://www.google.com' }
    it "takes a URI as input" do
      HTTParty::ConnectionAdapter.new(uri)
    end

    it "raises an ArgumentError if the uri is nil" do
      expect { HTTParty::ConnectionAdapter.new(nil) }.to raise_error ArgumentError
    end

    it "raises an ArgumentError if the uri is a String" do
      expect { HTTParty::ConnectionAdapter.new('http://www.google.com') }.to raise_error ArgumentError
    end

    it "sets the uri" do
      adapter = HTTParty::ConnectionAdapter.new(uri)
      expect(adapter.uri).to be uri
    end

    it "also accepts an optional options hash" do
      HTTParty::ConnectionAdapter.new(uri, {})
    end

    it "sets the options" do
      options = {foo: :bar}
      adapter = HTTParty::ConnectionAdapter.new(uri, options)
      expect(adapter.options).to be options
    end
  end

  describe ".call" do
    it "generates an HTTParty::ConnectionAdapter instance with the given uri and options" do
      expect(HTTParty::ConnectionAdapter).to receive(:new).with(@uri, @options).and_return(double(connection: nil))
      HTTParty::ConnectionAdapter.call(@uri, @options)
    end

    it "calls #connection on the connection adapter" do
      adapter = double('Adapter')
      connection = double('Connection')
      expect(adapter).to receive(:connection).and_return(connection)
      allow(HTTParty::ConnectionAdapter).to receive_messages(new: adapter)
      expect(HTTParty::ConnectionAdapter.call(@uri, @options)).to be connection
    end
  end

  describe '#connection' do
    let(:uri) { URI 'http://www.google.com' }
    let(:options) { Hash.new }
    let(:adapter) { HTTParty::ConnectionAdapter.new(uri, options) }

    describe "the resulting connection" do
      subject { adapter.connection }
      it { is_expected.to be_an_instance_of Net::HTTP }

      context "using port 80" do
        let(:uri) { URI 'http://foobar.com' }
        it { is_expected.not_to use_ssl }
      end

      context "when dealing with ssl" do
        let(:uri) { URI 'https://foobar.com' }

        context "uses the system cert_store, by default" do
          let!(:system_cert_store) do
            system_cert_store = double('default_cert_store')
            expect(system_cert_store).to receive(:set_default_paths)
            expect(OpenSSL::X509::Store).to receive(:new).and_return(system_cert_store)
            system_cert_store
          end
          it { is_expected.to use_cert_store(system_cert_store) }
        end

        context "should use the specified cert store, when one is given" do
          let(:custom_cert_store) { double('custom_cert_store') }
          let(:options) { {cert_store: custom_cert_store} }
          it { is_expected.to use_cert_store(custom_cert_store) }
        end

        context "using port 443 for ssl" do
          let(:uri) { URI 'https://api.foo.com/v1:443' }
          it { is_expected.to use_ssl }
        end

        context "https scheme with default port" do
          it { is_expected.to use_ssl }
        end

        context "https scheme with non-standard port" do
          let(:uri) { URI 'https://foobar.com:123456' }
          it { is_expected.to use_ssl }
        end

        context "when ssl version is set" do
          let(:options) { {ssl_version: :TLSv1} }

          it "sets ssl version" do
            expect(subject.ssl_version).to eq(:TLSv1)
          end
        end if RUBY_VERSION > '1.9'
      end

      context "when dealing with IPv6" do
        let(:uri) { URI 'http://[fd00::1]' }

        it "strips brackets from the address" do
          expect(subject.address).to eq('fd00::1')
        end
      end

      context "specifying ciphers" do
        let(:options) { {ciphers: 'RC4-SHA' } }

        it "should set the ciphers on the connection" do
          expect(subject.ciphers).to eq('RC4-SHA')
        end
      end if RUBY_VERSION > '1.9'

      context "when timeout is not set" do
        it "doesn't set the timeout" do
          http = double(
            "http",
            :null_object => true,
            :use_ssl= => false,
            :use_ssl? => false
          )
          expect(http).not_to receive(:open_timeout=)
          expect(http).not_to receive(:read_timeout=)
          allow(Net::HTTP).to receive_messages(new: http)

          adapter.connection
        end
      end

      context "when setting timeout" do
        context "to 5 seconds" do
          let(:options) { {timeout: 5} }

          describe '#open_timeout' do
            subject { super().open_timeout }
            it { is_expected.to eq(5) }
          end

          describe '#read_timeout' do
            subject { super().read_timeout }
            it { is_expected.to eq(5) }
          end
        end

        context "and timeout is a string" do
          let(:options) { {timeout: "five seconds"} }

          it "doesn't set the timeout" do
            http = double(
              "http",
              :null_object => true,
              :use_ssl= => false,
              :use_ssl? => false
            )
            expect(http).not_to receive(:open_timeout=)
            expect(http).not_to receive(:read_timeout=)
            allow(Net::HTTP).to receive_messages(new: http)

            adapter.connection
          end
        end
      end

      context "when timeout is not set and read_timeout is set to 6 seconds" do
        let(:options) { {read_timeout: 6} }

        describe '#read_timeout' do
          subject { super().read_timeout }
          it { is_expected.to eq(6) }
        end

        it "should not set the open_timeout" do
          http = double(
            "http",
            :null_object => true,
            :use_ssl= => false,
            :use_ssl? => false,
            :read_timeout= => 0
          )
          expect(http).not_to receive(:open_timeout=)
          allow(Net::HTTP).to receive_messages(new: http)
          adapter.connection
        end
      end

      context "when timeout is set and read_timeout is set to 6 seconds" do
        let(:options) { {timeout: 5, read_timeout: 6} }

        describe '#open_timeout' do
          subject { super().open_timeout }
          it { is_expected.to eq(5) }
        end

        describe '#read_timeout' do
          subject { super().read_timeout }
          it { is_expected.to eq(6) }
        end

        it "should override the timeout option" do
          http = double(
            "http",
            :null_object => true,
            :use_ssl= => false,
            :use_ssl? => false,
            :read_timeout= => 0,
            :open_timeout= => 0
          )
          expect(http).to receive(:open_timeout=)
          expect(http).to receive(:read_timeout=).twice
          allow(Net::HTTP).to receive_messages(new: http)
          adapter.connection
        end
      end

      context "when timeout is not set and open_timeout is set to 7 seconds" do
        let(:options) { {open_timeout: 7} }

        describe '#open_timeout' do
          subject { super().open_timeout }
          it { is_expected.to eq(7) }
        end

        it "should not set the read_timeout" do
          http = double(
            "http",
            :null_object => true,
            :use_ssl= => false,
            :use_ssl? => false,
            :open_timeout= => 0
          )
          expect(http).not_to receive(:read_timeout=)
          allow(Net::HTTP).to receive_messages(new: http)
          adapter.connection
        end
      end

      context "when timeout is set and open_timeout is set to 7 seconds" do
        let(:options) { {timeout: 5, open_timeout: 7} }

        describe '#open_timeout' do
          subject { super().open_timeout }
          it { is_expected.to eq(7) }
        end

        describe '#read_timeout' do
          subject { super().read_timeout }
          it { is_expected.to eq(5) }
        end

        it "should override the timeout option" do
          http = double(
            "http",
            :null_object => true,
            :use_ssl= => false,
            :use_ssl? => false,
            :read_timeout= => 0,
            :open_timeout= => 0
          )
          expect(http).to receive(:open_timeout=).twice
          expect(http).to receive(:read_timeout=)
          allow(Net::HTTP).to receive_messages(new: http)
          adapter.connection
        end
      end

      context "when debug_output" do
        let(:http) { Net::HTTP.new(uri) }
        before do
          allow(Net::HTTP).to receive_messages(new: http)
        end

        context "is set to $stderr" do
          let(:options) { {debug_output: $stderr} }
          it "has debug output set" do
            expect(http).to receive(:set_debug_output).with($stderr)
            adapter.connection
          end
        end

        context "is not provided" do
          it "does not set_debug_output" do
            expect(http).not_to receive(:set_debug_output)
            adapter.connection
          end
        end
      end

      context 'when providing proxy address and port' do
        let(:options) { {http_proxyaddr: '1.2.3.4', http_proxyport: 8080} }

        it { is_expected.to be_a_proxy }

        describe '#proxy_address' do
          subject { super().proxy_address }
          it { is_expected.to eq('1.2.3.4') }
        end

        describe '#proxy_port' do
          subject { super().proxy_port }
          it { is_expected.to eq(8080) }
        end

        context 'as well as proxy user and password' do
          let(:options) do
            {http_proxyaddr: '1.2.3.4', http_proxyport: 8080,
             http_proxyuser: 'user', http_proxypass: 'pass'}
          end

          describe '#proxy_user' do
            subject { super().proxy_user }
            it { is_expected.to eq('user') }
          end

          describe '#proxy_pass' do
            subject { super().proxy_pass }
            it { is_expected.to eq('pass') }
          end
        end
      end

      context 'when not providing a proxy address' do
        let(:uri) { URI 'http://proxytest.com' }

        it "does not pass any proxy parameters to the connection" do
          http = Net::HTTP.new("proxytest.com")
          expect(Net::HTTP).to receive(:new).once.with("proxytest.com", 80).and_return(http)
          adapter.connection
        end
      end

      context 'when providing a local bind address and port' do
        let(:options) { {local_host: "127.0.0.1", local_port: 12345 } }

        describe '#local_host' do
          subject { super().local_host }
          it { is_expected.to eq('127.0.0.1') }
        end

        describe '#local_port' do
          subject { super().local_port }
          it { is_expected.to eq(12345) }
        end
      end if RUBY_VERSION >= '2.0'

      context "when providing PEM certificates" do
        let(:pem) { :pem_contents }
        let(:options) { {pem: pem, pem_password: "password"} }

        context "when scheme is https" do
          let(:uri) { URI 'https://google.com' }
          let(:cert) { double("OpenSSL::X509::Certificate") }
          let(:key) { double("OpenSSL::PKey::RSA") }

          before do
            expect(OpenSSL::X509::Certificate).to receive(:new).with(pem).and_return(cert)
            expect(OpenSSL::PKey::RSA).to receive(:new).with(pem, "password").and_return(key)
          end

          it "uses the provided PEM certificate" do
            expect(subject.cert).to eq(cert)
            expect(subject.key).to eq(key)
          end

          it "will verify the certificate" do
            expect(subject.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
          end

          context "when options include verify_peer=false" do
            let(:options) { {pem: pem, pem_password: "password", verify_peer: false} }

            it "should not verify the certificate" do
              expect(subject.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
            end
          end
        end

        context "when scheme is not https" do
          let(:uri) { URI 'http://google.com' }
          let(:http) { Net::HTTP.new(uri) }

          before do
            allow(Net::HTTP).to receive_messages(new: http)
            expect(OpenSSL::X509::Certificate).not_to receive(:new).with(pem)
            expect(OpenSSL::PKey::RSA).not_to receive(:new).with(pem, "password")
            expect(http).not_to receive(:cert=)
            expect(http).not_to receive(:key=)
          end

          it "has no PEM certificate " do
            expect(subject.cert).to be_nil
            expect(subject.key).to be_nil
          end
        end
      end

      context "when providing PKCS12 certificates" do
        let(:p12) { :p12_contents }
        let(:options) { {p12: p12, p12_password: "password"} }

        context "when scheme is https" do
          let(:uri) { URI 'https://google.com' }
          let(:pkcs12) { double("OpenSSL::PKCS12", certificate: cert, key: key) }
          let(:cert) { double("OpenSSL::X509::Certificate") }
          let(:key) { double("OpenSSL::PKey::RSA") }

          before do
            expect(OpenSSL::PKCS12).to receive(:new).with(p12, "password").and_return(pkcs12)
          end

          it "uses the provided P12 certificate " do
            expect(subject.cert).to eq(cert)
            expect(subject.key).to eq(key)
          end

          it "will verify the certificate" do
            expect(subject.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
          end

          context "when options include verify_peer=false" do
            let(:options) { {p12: p12, p12_password: "password", verify_peer: false} }

            it "should not verify the certificate" do
              expect(subject.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
            end
          end
        end

        context "when scheme is not https" do
          let(:uri) { URI 'http://google.com' }
          let(:http) { Net::HTTP.new(uri) }

          before do
            allow(Net::HTTP).to receive_messages(new: http)
            expect(OpenSSL::PKCS12).not_to receive(:new).with(p12, "password")
            expect(http).not_to receive(:cert=)
            expect(http).not_to receive(:key=)
          end

          it "has no PKCS12 certificate " do
            expect(subject.cert).to be_nil
            expect(subject.key).to be_nil
          end
        end
      end

      context "when uri port is not defined" do
        context "falls back to 80 port on http" do
          let(:uri) { URI 'http://foobar.com' }
          before { allow(uri).to receive(:port).and_return(nil) }
          it { expect(subject.port).to be 80 }
        end

        context "falls back to 443 port on https" do
          let(:uri) { URI 'https://foobar.com' }
          before { allow(uri).to receive(:port).and_return(nil) }
          it { expect(subject.port).to be 443 }
        end
      end
    end
  end
end
