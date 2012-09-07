require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::ConnectionAdapter do

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
      adapter.uri.should be uri
    end

    it "also accepts an optional options hash" do
      HTTParty::ConnectionAdapter.new(uri, {})
    end

    it "sets the options" do
      options = {:foo => :bar}
      adapter = HTTParty::ConnectionAdapter.new(uri, options)
      adapter.options.should be options
    end
  end

  describe ".call" do
    it "generates an HTTParty::ConnectionAdapter instance with the given uri and options" do
      HTTParty::ConnectionAdapter.should_receive(:new).with(@uri, @options).and_return(stub(:connection => nil))
      HTTParty::ConnectionAdapter.call(@uri, @options)
    end

    it "calls #connection on the connection adapter" do
      adapter = mock('Adapter')
      connection = mock('Connection')
      adapter.should_receive(:connection).and_return(connection)
      HTTParty::ConnectionAdapter.stub(:new => adapter)
      HTTParty::ConnectionAdapter.call(@uri, @options).should be connection
    end
  end

  describe '#connection' do
    let(:uri) { URI 'http://www.google.com' }
    let(:options) { Hash.new }
    let(:adapter) { HTTParty::ConnectionAdapter.new(uri, options) }

    describe "the resulting connection" do
      subject { adapter.connection }
      it { should be_an_instance_of Net::HTTP }

      context "using port 80" do
        let(:uri) { URI 'http://foobar.com' }
        it { should_not use_ssl }
      end

      context "when dealing with ssl" do
        let(:uri) { URI 'https://foobar.com' }

        context "using port 443 for ssl" do
          let(:uri) { URI 'https://api.foo.com/v1:443' }
          it { should use_ssl }
        end

        context "https scheme with default port" do
          it { should use_ssl }
        end

        context "https scheme with non-standard port" do
          let(:uri) { URI 'https://foobar.com:123456' }
          it { should use_ssl }
        end

        context "when ssl version is set" do
          let(:options) { {:ssl_version => :TLSv1} }

          it "sets ssl version" do
            subject.ssl_version.should == :TLSv1
          end
        end if RUBY_VERSION > '1.9'
      end

      context "when timeout is not set" do
        it "doesn't set the timeout" do
          http = mock("http", :null_object => true)
          http.should_not_receive(:open_timeout=)
          http.should_not_receive(:read_timeout=)
          Net::HTTP.stub(:new => http)

          adapter.connection
        end
      end

      context "when setting timeout" do
        context "to 5 seconds" do
          let(:options) { {:timeout => 5} }

          its(:open_timeout) { should == 5 }
          its(:read_timeout) { should == 5 }
        end

        context "and timeout is a string" do
          let(:options) { {:timeout => "five seconds"} }

          it "doesn't set the timeout" do
            http = mock("http", :null_object => true)
            http.should_not_receive(:open_timeout=)
            http.should_not_receive(:read_timeout=)
            Net::HTTP.stub(:new => http)

            adapter.connection
          end
        end
      end

      context "when debug_output" do
        let(:http) { Net::HTTP.new(uri) }
        before do
          Net::HTTP.stub(:new => http)
        end

        context "is set to $stderr" do
          let(:options) { {:debug_output => $stderr} }
          it "has debug output set" do
            http.should_receive(:set_debug_output).with($stderr)
            adapter.connection
          end
        end

        context "is not provided" do
          it "does not set_debug_output" do
            http.should_not_receive(:set_debug_output)
            adapter.connection
          end
        end
      end

      context 'when providing proxy address and port' do
        let(:options) { {:http_proxyaddr => '1.2.3.4', :http_proxyport => 8080} }

        it { should be_a_proxy }
        its(:proxy_address) { should == '1.2.3.4' }
        its(:proxy_port) { should == 8080 }

        context 'as well as proxy user and password' do
          let(:options) do
            {:http_proxyaddr => '1.2.3.4', :http_proxyport => 8080,
             :http_proxyuser => 'user', :http_proxypass => 'pass'}
          end
          its(:proxy_user) { should == 'user' }
          its(:proxy_pass) { should == 'pass' }
        end
      end

      context "when providing PEM certificates" do
        let(:pem) { :pem_contents }
        let(:options) { {:pem => pem, :pem_password => "password"} }

        context "when scheme is https" do
          let(:uri) { URI 'https://google.com' }
          let(:cert) { mock("OpenSSL::X509::Certificate") }
          let(:key) { mock("OpenSSL::PKey::RSA") }

          before do
            OpenSSL::X509::Certificate.should_receive(:new).with(pem).and_return(cert)
            OpenSSL::PKey::RSA.should_receive(:new).with(pem, "password").and_return(key)
          end

          it "uses the provided PEM certificate " do
            subject.cert.should == cert
            subject.key.should == key
          end

          it "will verify the certificate" do
            subject.verify_mode.should == OpenSSL::SSL::VERIFY_PEER
          end
        end

        context "when scheme is not https" do
          let(:uri) { URI 'http://google.com' }
          let(:http) { Net::HTTP.new(uri) }

          before do
            Net::HTTP.stub(:new => http)
            OpenSSL::X509::Certificate.should_not_receive(:new).with(pem)
            OpenSSL::PKey::RSA.should_not_receive(:new).with(pem, "password")
            http.should_not_receive(:cert=)
            http.should_not_receive(:key=)
          end

          it "has no PEM certificate " do
            subject.cert.should be_nil
            subject.key.should be_nil
          end
        end
      end
    end
  end
end
