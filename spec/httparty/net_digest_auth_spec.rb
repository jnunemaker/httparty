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

  def cookie_header
    @digest.cookie_header
  end

  context 'Net::HTTPHeader#digest_auth' do
    let(:headers) {
      (Class.new do 
        include Net::HTTPHeader
        def initialize
          @header = {}
          @path = '/'
          @method = 'GET'
        end
      end).new
    } 

    let(:response){
      (Class.new do 
        include Net::HTTPHeader
        def initialize
          @header = {}
          self['WWW-Authenticate'] = 
          'Digest realm="testrealm@host.com", qop="auth,auth-int", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
        end
      end).new
    }

    it 'should set the authorization header' do 
      expect(headers['authorization']).to be_nil
      headers.digest_auth('user','pass', response)
      expect(headers['authorization']).to_not be_empty
    end 
  end 

  context "with a cookie value in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com"',
        'Set-Cookie' => 'custom-cookie=1234567'
      })
    end

    it "should set cookie header" do
      expect(cookie_header).to include('custom-cookie=1234567')
    end
  end

  context "without a cookie value in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com"'
      })
    end

    it "should set empty cookie header array" do
      expect(cookie_header).to eql []
    end
  end

  context "with an opaque value in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", opaque="solid"'
      })
    end

    it "should set opaque" do
      expect(authorization_header).to include('opaque="solid"')
    end
  end

  context "without an opaque valid in the response header" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com"'
      })
    end

    it "should not set opaque" do
      expect(authorization_header).not_to include("opaque=")
    end
  end

  context "with specified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth"'
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include('username="Mufasa"')
    end

    it "should set digest-uri" do
      expect(authorization_header).to include('uri="/dir/index.html"')
    end

    it "should set qop" do
      expect(authorization_header).to include('qop="auth"')
    end

    it "should set cnonce" do
      expect(authorization_header).to include('cnonce="md5(deadbeef)"')
    end

    it "should set nonce-count" do
      expect(authorization_header).to include("nc=00000001")
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:00000001:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%(response="#{request_digest}"))
    end
  end

  context "when quality of protection (qop) is unquoted" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop=auth'
      })
    end

    it "should still set qop" do
      expect(authorization_header).to include('qop="auth"')
    end
  end

  context "with unspecified quality of protection (qop)" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE"'
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include('username="Mufasa"')
    end

    it "should set digest-uri" do
      expect(authorization_header).to include('uri="/dir/index.html"')
    end

    it "should not set qop" do
      expect(authorization_header).not_to include("qop=")
    end

    it "should not set cnonce" do
      expect(authorization_header).not_to include("cnonce=")
    end

    it "should not set nonce-count" do
      expect(authorization_header).not_to include("nc=")
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%(response="#{request_digest}"))
    end
  end

  context "with http basic auth response when net digest auth expected" do
    it "should not fail" do
      @digest = setup_digest({
                               'www-authenticate' => 'WWW-Authenticate: Basic realm="testrealm.com""'
                           })

      expect(authorization_header).to include("Digest")
    end
  end

  context "with multiple authenticate headers" do
    before do
      @digest = setup_digest({
        'www-authenticate' => 'NTLM, Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth"'
      })
    end

    it "should set prefix" do
      expect(authorization_header).to match(/^Digest /)
    end

    it "should set username" do
      expect(authorization_header).to include('username="Mufasa"')
    end

    it "should set digest-uri" do
      expect(authorization_header).to include('uri="/dir/index.html"')
    end

    it "should set qop" do
      expect(authorization_header).to include('qop="auth"')
    end

    it "should set cnonce" do
      expect(authorization_header).to include('cnonce="md5(deadbeef)"')
    end

    it "should set nonce-count" do
      expect(authorization_header).to include("nc=00000001")
    end

    it "should set response" do
      request_digest = "md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:00000001:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%(response="#{request_digest}"))
    end
  end
  
  context "with algorithm specified" do
    before do
      @digest = setup_digest({
                              'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth", algorithm=MD5'
                             })
    end
    
    it "should recognise algorithm was specified" do
      expect( @digest.send :algorithm_present? ).to be(true)
    end
    
    it "should set the algorithm header" do
      expect(authorization_header).to include('algorithm="MD5"')
    end
  end

  context "with md5-sess algorithm specified" do
    before do
      @digest = setup_digest({
                              'www-authenticate' => 'Digest realm="myhost@testrealm.com", nonce="NONCE", qop="auth", algorithm=MD5-sess'
                             })
    end
    
    it "should recognise algorithm was specified" do
      expect( @digest.send :algorithm_present? ).to be(true)
    end
    
    it "should set the algorithm header" do
      expect(authorization_header).to include('algorithm="MD5-sess"')
    end
    
    it "should set response using md5-sess algorithm" do
      request_digest = "md5(md5(md5(Mufasa:myhost@testrealm.com:Circle Of Life):NONCE:md5(deadbeef)):NONCE:00000001:md5(deadbeef):auth:md5(GET:/dir/index.html))"
      expect(authorization_header).to include(%(response="#{request_digest}"))
    end
    
  end
  
end
