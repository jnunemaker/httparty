require 'spec_helper'

# Credentials go only to the origin (scheme, host and port) they were given
# for, as curl, Python requests and browsers do. An http -> https upgrade on
# the default ports keeps them.
RSpec.describe HTTParty::Request, "credentials across redirects" do
  def follow(from, to, **options)
    stub_request(:get, from).to_return(status: 302, headers: { "Location" => to })
    target = to.start_with?("//") ? "#{URI(from).scheme}:#{to}" : URI.join(from, to).to_s
    stub_request(:get, target).to_return(body: "ok")
    HTTParty.get(from, **options)
    target
  end

  def authorization_sent_to(url)
    sent = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.select { |s| s.uri.to_s.sub(":443/", "/").sub(":80/", "/") == url }
    sent.map { |s| s.headers&.find { |k, _| k.casecmp?("authorization") }&.last }
  end

  token = { headers: { "Authorization" => "Bearer secret" } }
  basic = { basic_auth: { username: "user", password: "pass" } }

  {
    "a different host" => ["https://api.example.com/start", "https://other.example.com/landing"],
    "a different host, as a scheme-relative Location" => ["https://api.example.com/start", "//other.example.com/landing"],
    "the same host over http (a downgrade)" => ["https://api.example.com/start", "http://api.example.com/landing"],
    "the same host on a different port" => ["https://api.example.com/start", "https://api.example.com:8443/landing"]
  }.each do |description, (from, to)|
    context "when redirected to #{description}" do
      it "does not send an Authorization header" do
        target = follow(from, to, **token)
        expect(authorization_sent_to(target)).to eq([nil])
      end

      it "does not send an authorization header given in lowercase" do
        target = follow(from, to, headers: { "authorization" => "Bearer secret" })
        expect(authorization_sent_to(target)).to eq([nil])
      end

      it "does not send basic auth" do
        target = follow(from, to, **basic)
        expect(authorization_sent_to(target)).to eq([nil])
      end
    end
  end

  {
    "the same host and scheme" => ["https://api.example.com/start", "/landing"],
    "the same host upgraded from http to https" => ["http://api.example.com/start", "https://api.example.com/landing"]
  }.each do |description, (from, to)|
    context "when redirected to #{description}" do
      it "keeps sending the Authorization header" do
        target = follow(from, to, **token)
        expect(authorization_sent_to(target)).to eq(["Bearer secret"])
      end

      it "keeps sending basic auth" do
        target = follow(from, to, **basic)
        expect(authorization_sent_to(target)).to eq(["Basic #{["user:pass"].pack('m0')}"])
      end
    end
  end

  context "with the Addressable URI adapter" do
    it "drops the Authorization header for a different host" do
      target = follow("https://api.example.com/start", "https://other.example.com/landing", uri_adapter: Addressable::URI, **token)
      expect(authorization_sent_to(target)).to eq([nil])
    end

    it "keeps it for an http -> https upgrade on the same host" do
      target = follow("http://api.example.com/start", "https://api.example.com/landing", uri_adapter: Addressable::URI, **token)
      expect(authorization_sent_to(target)).to eq(["Bearer secret"])
    end
  end

  it "keeps the Authorization header out after redirecting back to the original host" do
    stub_request(:get, "https://api.example.com/start").to_return(status: 302, headers: { "Location" => "https://other.example.com/hop" })
    stub_request(:get, "https://other.example.com/hop").to_return(status: 302, headers: { "Location" => "https://api.example.com/back" })
    stub_request(:get, "https://api.example.com/back").to_return(body: "ok")
    HTTParty.get("https://api.example.com/start", **token)
    expect(authorization_sent_to("https://api.example.com/back")).to eq([nil])
  end

  it "does not change the headers hash passed in" do
    headers = { "Authorization" => "Bearer secret" }
    request = HTTParty::Request.new(Net::HTTP::Get, "https://api.example.com/start", headers: headers)
    stub_request(:get, "https://api.example.com/start").to_return(status: 302, headers: { "Location" => "https://other.example.com/landing" })
    stub_request(:get, "https://other.example.com/landing").to_return(body: "ok")
    request.perform
    expect(headers).to eq("Authorization" => "Bearer secret")
  end

  it "does not answer a digest challenge from a different host" do
    stub_request(:get, "https://api.example.com/start").to_return(status: 302, headers: { "Location" => "https://other.example.com/landing" })
    stub_request(:get, "https://other.example.com/landing").to_return(
      status: 401,
      headers: { "WWW-Authenticate" => 'Digest realm="other", qop="auth", nonce="abc", opaque="def"' }
    )
    response = HTTParty.get("https://api.example.com/start", digest_auth: { username: "user", password: "pass" })
    expect(response.code).to eq(401)
    expect(authorization_sent_to("https://other.example.com/landing")).to eq([nil])
  end
end
