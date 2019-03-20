require 'spec_helper'

RSpec.describe HTTParty::Request do
  context "SSL certificate verification" do
    before do
      WebMock.disable!
    end

    after do
      WebMock.enable!
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

    it "should work when no trusted CA list is specified, even with a bogus hostname, when the verify option is set to true" do
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
      response = double(Net::HTTPResponse, :[] => '', body: '', to_hash: {})
      allow(http).to receive(:request).and_return(response)
      expect(Net::HTTP).to receive(:new).with('www.google.com', 443).and_return(http)
      expect(http).to receive(:ca_path=).with('/foo/bar')
      HTTParty.get('https://www.google.com', ssl_ca_path: '/foo/bar')
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
