require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::Request do
  context "SSL certificate verification" do
    before do
      FakeWeb.allow_net_connect = true
    end

    after do
      FakeWeb.allow_net_connect = false
    end

    it "should work when no trusted CA list is specified" do
      ssl_verify_test(nil, nil, "selfsigned.crt").should == {'success' => true}
    end

    it "should work when no trusted CA list is specified, even with a bogus hostname" do
      ssl_verify_test(nil, nil, "bogushost.crt").should == {'success' => true}
    end

    it "should work when using ssl_ca_file with a self-signed CA" do
      ssl_verify_test(:ssl_ca_file, "selfsigned.crt", "selfsigned.crt").should == {'success' => true}
    end

    it "should work when using ssl_ca_file with a certificate authority" do
      ssl_verify_test(:ssl_ca_file, "ca.crt", "server.crt").should == {'success' => true}
    end

    it "should work when using ssl_ca_path with a certificate authority" do
      http = Net::HTTP.new('www.google.com', 443, nil, nil, nil, nil)
      response = stub(Net::HTTPResponse, :[] => '', :body => '', :to_hash => {})
      http.stub(:request).and_return(response)
      Net::HTTP.should_receive(:new).with('www.google.com', 443, nil, nil, nil, nil).and_return(http)
      http.should_receive(:ca_path=).with('/foo/bar')
      HTTParty.get('https://www.google.com', :ssl_ca_path => '/foo/bar')
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
