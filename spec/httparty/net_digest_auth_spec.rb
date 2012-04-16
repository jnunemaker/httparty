require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Net::HTTPHeader::DigestAuthenticator do
  def setup_digest(response)
    digest = Net::HTTPHeader::DigestAuthenticator.new("Mufasa",
      "Circle Of Life", "GET", "/dir/index.html", response)
    digest.stub(:random).and_return("deadbeef")
    Digest::MD5.stub(:hexdigest) { |str| "md5(#{str})" }
    digest
  end

  def authorization_header
    @digest.authorization_header.join(", ")
  end

  context "with specified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth"',
      })
    end

    it "should set prefix" do
      authorization_header.should =~ /^Digest /
    end

    it "should set username" do
      authorization_header.should include(%Q(username="Mufasa"))
    end

    it "should set digest-uri" do
      authorization_header.should include(%Q(uri="/dir/index.html"))
    end

    it "should set qop" do
      authorization_header.should include(%Q(qop="auth"))
    end

    it "should set cnonce" do
      authorization_header.should include(%Q(cnonce="md5(deadbeef)"))
    end

    it "should set nonce-count" do
      authorization_header.should include(%Q(nc="0"))
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:0:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      authorization_header.should include(%Q(response="#{request_digest}"))
    end
  end


  context "with unspecified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE"',
      })
    end

    it "should set prefix" do
      authorization_header.should =~ /^Digest /
    end

    it "should set username" do
      authorization_header.should include(%Q(username="Mufasa"))
    end

    it "should set digest-uri" do
      authorization_header.should include(%Q(uri="/dir/index.html"))
    end

    it "should not set qop" do
      authorization_header.should_not include(%Q(qop=))
    end

    it "should not set cnonce" do
      authorization_header.should_not include(%Q(cnonce=))
    end

    it "should not set nonce-count" do
      authorization_header.should_not include(%Q(nc=))
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:md5(GET:/dir/index.html))"
      authorization_header.should include(%Q(response="#{request_digest}"))
    end
  end
end
