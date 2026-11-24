require 'spec_helper'

RSpec.describe HTTParty::Request do
  context "SSL certificate verification" do
    before do
      WebMock.disable!
    end

    after do
      WebMock.enable!
    end

    # A c_rehash-style directory holding the test CA, for ssl_ca_path
    def with_hashed_ca_dir
      ca_file = File.expand_path("../../fixtures/ssl/generated/ca.crt", __FILE__)
      ca = OpenSSL::X509::Certificate.new(File.read(ca_file))
      Dir.mktmpdir do |dir|
        FileUtils.cp(ca_file, File.join(dir, format("%08x.0", ca.subject.hash)))
        yield dir
      end
    end

    # A root certificate from the system's default CA bundle
    def system_ca_certificate
      bundle = File.read(OpenSSL::X509::DEFAULT_CERT_FILE)
      OpenSSL::X509::Certificate.new(bundle[/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m])
    end

    it "keeps the test server serving after a client that can't complete a handshake" do
      fixtures = File.expand_path("../../fixtures/ssl/generated", __FILE__)
      server = SSLTestServer.new(
        rsa_key: File.read("#{fixtures}/server.key"),
        cert:    File.read("#{fixtures}/selfsigned.crt")
      )
      server.start

      TCPSocket.open("localhost", server.port) do |plain_client|
        plain_client.write("GET / HTTP/1.1\r\n\r\n")
        plain_client.read rescue nil
      end

      response = HTTParty.get("https://localhost:#{server.port}/", format: :json, verify: false, timeout: 30)
      expect(response.parsed_response).to eq("success" => true)
      expect { server.stop }.not_to raise_error
    end

    context "with a verify_callback" do
      it "calls it for each certificate in the server's chain during the handshake" do
        seen = []
        callback = ->(preverify_ok, store_context) { seen << [preverify_ok, store_context.current_cert.subject.to_s]; preverify_ok }

        response = ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt", verify_callback: callback)

        expect(response.parsed_response).to eq({'success' => true})
        expect(seen).not_to be_empty
        expect(seen.map(&:first)).to all(be true)
      end

      it "fails the handshake when the callback returns false" do
        expect do
          ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt", verify_callback: ->(_ok, _ctx) { false })
        end.to raise_error(OpenSSL::SSL::SSLError)
      end
    end

    it "should fail when no trusted CA list is specified, by default" do
      expect do
        ssl_verify_test(nil, nil, "selfsigned.crt")
      end.to raise_error OpenSSL::SSL::SSLError
    end

    it "should work when no trusted CA list is specified, when the verify option is set to false" do
      expect(ssl_verify_test(nil, nil, "selfsigned.crt", verify: false).parsed_response).to eq({'success' => true})
    end

    it "should fail when no trusted CA list is specified, with a bogus hostname, by default" do
      expect do
        ssl_verify_test(nil, nil, "bogushost.crt")
      end.to raise_error OpenSSL::SSL::SSLError
    end

    it "should work when no trusted CA list is specified, even with a bogus hostname, when the verify option is set to false" do
      expect(ssl_verify_test(nil, nil, "bogushost.crt", verify: false).parsed_response).to eq({'success' => true})
    end

    it "should work when using ssl_ca_file with a self-signed CA" do
      expect(ssl_verify_test(:ssl_ca_file, "selfsigned.crt", "selfsigned.crt").parsed_response).to eq({'success' => true})
    end

    it "should work when using ssl_ca_file with a certificate authority" do
      expect(ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt").parsed_response).to eq({'success' => true})
    end

    it "should work when using ssl_ca_path with a certificate authority" do
      http = Net::HTTP.new('www.google.com', 443)
      response = double(Net::HTTPResponse, :[] => '', body: '', to_hash: {}, delete: nil)
      allow(http).to receive(:request).and_return(response)
      expect(Net::HTTP).to receive(:new).with('www.google.com', 443).and_return(http)
      expect(http).to receive(:ca_path=).with('/foo/bar')
      HTTParty.get('https://www.google.com', ssl_ca_path: '/foo/bar')
    end

    # The default cert store is shared by every request, so loading a request's
    # CA into it would make later requests trust that CA too.
    context "after a request that trusted its own certificate authority" do
      it "does not trust an ssl_ca_file for requests without it" do
        expect(ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt").parsed_response).to eq({'success' => true})
        expect { ssl_verify_test(nil, nil, "server.crt") }.to raise_error(OpenSSL::SSL::SSLError)
      end

      it "does not trust an ssl_ca_path for requests without it" do
        with_hashed_ca_dir do |dir|
          expect(ssl_verify_test(nil, nil, "server.crt", ssl_ca_path: dir).parsed_response).to eq({'success' => true})
        end
        expect { ssl_verify_test(nil, nil, "server.crt") }.to raise_error(OpenSSL::SSL::SSLError)
      end

      it "still trusts the system certificate authorities along with the ssl_ca_file" do
        connection = HTTParty::ConnectionAdapter.call(URI("https://example.com"), ssl_ca_file: "ca.crt")
        expect(connection.cert_store.verify(system_ca_certificate)).to be(true)
      end
    end

    it "should fail when using ssl_ca_file and the server uses an unrecognized certificate authority" do
      expect do
        ssl_verify_test(:ssl_ca_file, "ca.crt", "selfsigned.crt")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should fail when using ssl_ca_path and the server uses an unrecognized certificate authority" do
      expect do
        ssl_verify_test(:ssl_ca_path, ".", "selfsigned.crt")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should fail when using ssl_ca_file and the server uses a bogus hostname" do
      expect do
        ssl_verify_test(:ssl_ca_file, "ca.crt", "bogushost.crt")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should fail when using ssl_ca_path and the server uses a bogus hostname" do
      expect do
        ssl_verify_test(:ssl_ca_path, ".", "bogushost.crt")
      end.to raise_error(OpenSSL::SSL::SSLError)
    end

    it "should provide the certificate used by the server via peer_cert" do
      peer_cert = nil
      ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt") do |response|
        peer_cert ||= response.connection.peer_cert
      end
      expect(peer_cert).to be_a OpenSSL::X509::Certificate
    end
  end
end
