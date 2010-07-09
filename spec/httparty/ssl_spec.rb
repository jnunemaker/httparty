require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::Request do
  context "SSL certificate verification" do
    before do
      FakeWeb.allow_net_connect = true    # enable network connections just for this test
    end

    after do
      FakeWeb.allow_net_connect = false   # Restore allow_net_connect value for testing
    end

    it "should work with when no trusted CA list is specified" do
      ssl_verify_test(nil, nil, "selfsigned.crt").should == {'success' => true}
    end

    it "should work with when no trusted CA list is specified, even with a bogus hostname" do
      ssl_verify_test(nil, nil, "bogushost.crt").should == {'success' => true}
    end

    it "should work when using ssl_ca_file with a self-signed CA" do
      ssl_verify_test(:ssl_ca_file, "selfsigned.crt", "selfsigned.crt").should == {'success' => true}
    end

    it "should work when using ssl_ca_file with a certificate authority" do
      ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt").should == {'success' => true}
    end
    it "should work when using ssl_ca_path with a certificate authority" do
      ssl_verify_test(:ssl_ca_path, ".", "server.crt").should == {'success' => true}
    end

    it "should fail when using ssl_ca_file and the server uses an unrecognized certificate authority" do
      lambda do
        ssl_verify_test(:ssl_ca_file, "ca.crt", "selfsigned.crt")
      end.should raise_error(OpenSSL::SSL::SSLError)
    end
    it "should fail when using ssl_ca_path and the server uses an unrecognized certificate authority" do
      lambda do
        ssl_verify_test(:ssl_ca_path, ".", "selfsigned.crt")
      end.should raise_error(OpenSSL::SSL::SSLError)
    end

    it "should fail when using ssl_ca_file and the server uses a bogus hostname" do
      lambda do
        ssl_verify_test(:ssl_ca_file, "ca.crt", "bogushost.crt")
      end.should raise_error(OpenSSL::SSL::SSLError)
    end
    it "should fail when using ssl_ca_path and the server uses a bogus hostname" do
      lambda do
        ssl_verify_test(:ssl_ca_path, ".", "bogushost.crt")
      end.should raise_error(OpenSSL::SSL::SSLError)
    end
  end
end
