require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe Net::HTTPHeader::DigestAuthenticator do
  def setup_digest(response)
    digest = Net::HTTPHeader::DigestAuthenticator.new("Mufasa",
      "Circle Of Life", "GET", "/dir/index.html", response)
    allow(digest).to receive(:random).and_return("deadbeef")
    allow(Digest::MD5).to receive(:hexdigest) { |str| "md5(#{str})" }
    digest
  end

  def authorization_header
    @digest.authorization_header.join(", ")
  end


  context "with an opaque value in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", opaque="solid"'
      })
    end

    it "should set opaque" do
      expect(authorization_header).to include(%Q(opaque="solid"))
    end
  end

  context "without an opaque valid in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com"'
      })
    end

    it "should not set opaque" do
      expect(authorization_header).not_to include(%Q(opaque=))
    end
  end

  context "with specified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth"',
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include(%Q(username="Mufasa"))
    end

    it "should set digest-uri" do
      expect(authorization_header).to include(%Q(uri="/dir/index.html"))
    end

    it "should set qop" do
      expect(authorization_header).to include(%Q(qop="auth"))
    end

    it "should set cnonce" do
      expect(authorization_header).to include(%Q(cnonce="md5(deadbeef)"))
    end

    it "should set nonce-count" do
      expect(authorization_header).to include(%Q(nc=00000001))
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:00000001:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%Q(response="#{request_digest}"))
    end
  end

  context "when quality of protection (qop) is unquoted" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop=auth',
      })
    end

    it "should still set qop" do
      expect(authorization_header).to include(%Q(qop="auth"))
    end
  end

  context "with unspecified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE"',
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include(%Q(username="Mufasa"))
    end

    it "should set digest-uri" do
      expect(authorization_header).to include(%Q(uri="/dir/index.html"))
    end

    it "should not set qop" do
      expect(authorization_header).not_to include(%Q(qop=))
    end

    it "should not set cnonce" do
      expect(authorization_header).not_to include(%Q(cnonce=))
    end

    it "should not set nonce-count" do
      expect(authorization_header).not_to include(%Q(nc=))
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%Q(response="#{request_digest}"))
    end
  end

  context "with multiple authenticate headers" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'NTLM, Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth"',
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include(%Q(username="Mufasa"))
    end

    it "should set digest-uri" do
      expect(authorization_header).to include(%Q(uri="/dir/index.html"))
    end

    it "should set qop" do
      expect(authorization_header).to include(%Q(qop="auth"))
    end

    it "should set cnonce" do
      expect(authorization_header).to include(%Q(cnonce="md5(deadbeef)"))
    end

    it "should set nonce-count" do
      expect(authorization_header).to include(%Q(nc=00000001))
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:00000001:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%Q(response="#{request_digest}"))
    end
  end
end
