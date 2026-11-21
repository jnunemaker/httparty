require 'spec_helper'

# Cookies stay with the origin (scheme, host and port) that set them or that
# they were given for, the same rule as credentials. HTTParty doesn't track the
# Set-Cookie Domain attribute, so on a redirect to another origin it sends no
# cookies from before the redirect. The new origin's own cookies are kept.
RSpec.describe HTTParty::Request, "cookies across redirects" do
  def cookie_sent_to(url)
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys
      .select { |s| s.uri.to_s.sub(":443/", "/").sub(":80/", "/") == url }
      .map { |s| s.headers&.find { |k, _| k.casecmp?("cookie") }&.last }
  end

  def redirect(from, to, set_cookie: nil)
    headers = { "Location" => to }
    headers["Set-Cookie"] = set_cookie if set_cookie
    stub_request(:get, from).to_return(status: 302, headers: headers)
  end

  let(:client) do
    Class.new do
      include HTTParty
      cookies(session: "class-secret")
    end
  end

  context "when redirected to a different host" do
    before do
      stub_request(:get, "https://other.example.com/landing").to_return(body: "ok")
    end

    it "does not send a Cookie header given in headers:" do
      redirect("https://api.example.com/start", "https://other.example.com/landing")
      HTTParty.get("https://api.example.com/start", headers: { "Cookie" => "session=secret" })
      expect(cookie_sent_to("https://other.example.com/landing")).to eq([nil])
    end

    it "does not send cookies given with the cookies: option" do
      redirect("https://api.example.com/start", "https://other.example.com/landing")
      HTTParty.get("https://api.example.com/start", cookies: { session: "secret" })
      expect(cookie_sent_to("https://other.example.com/landing")).to eq([nil])
    end

    it "does not send class-level cookies" do
      redirect("https://api.example.com/start", "https://other.example.com/landing")
      client.get("https://api.example.com/start")
      expect(cookie_sent_to("https://other.example.com/landing")).to eq([nil])
    end

    it "does not send cookies the previous host set in its redirect" do
      redirect("https://api.example.com/start", "https://other.example.com/landing", set_cookie: "a_sid=from-a; Path=/")
      HTTParty.get("https://api.example.com/start")
      expect(cookie_sent_to("https://other.example.com/landing")).to eq([nil])
    end

    it "keeps the new host's own cookies for its next redirect" do
      redirect("https://api.example.com/start", "https://other.example.com/hop", set_cookie: "a_sid=from-a")
      redirect("https://other.example.com/hop", "https://other.example.com/landing", set_cookie: "b_sid=from-b; Path=/")
      HTTParty.get("https://api.example.com/start", cookies: { session: "secret" })
      expect(cookie_sent_to("https://other.example.com/hop")).to eq([nil])
      expect(cookie_sent_to("https://other.example.com/landing")).to eq(["b_sid=from-b"])
    end
  end

  it "does not send cookies over an https -> http downgrade on the same host" do
    redirect("https://api.example.com/start", "http://api.example.com/landing")
    stub_request(:get, "http://api.example.com/landing").to_return(body: "ok")
    HTTParty.get("https://api.example.com/start", cookies: { session: "secret" })
    expect(cookie_sent_to("http://api.example.com/landing")).to eq([nil])
  end

  context "when redirected on the same origin" do
    before do
      stub_request(:get, "https://api.example.com/landing").to_return(body: "ok")
    end

    it "keeps sending your cookies" do
      redirect("https://api.example.com/start", "/landing")
      client.get("https://api.example.com/start")
      expect(cookie_sent_to("https://api.example.com/landing")).to eq(["session=class-secret"])
    end

    it "sends your cookies together with the ones the redirect set" do
      redirect("https://api.example.com/start", "/landing", set_cookie: "a_sid=from-a; Path=/; HttpOnly")
      client.get("https://api.example.com/start")
      expect(cookie_sent_to("https://api.example.com/landing").first.split("; ")).to contain_exactly("session=class-secret", "a_sid=from-a")
    end

    it "merges a lowercase cookie header given in headers: with the ones the redirect set" do
      redirect("https://api.example.com/start", "/landing", set_cookie: "a_sid=from-a")
      HTTParty.get("https://api.example.com/start", headers: { "cookie" => "session=secret" })
      expect(cookie_sent_to("https://api.example.com/landing").first.split("; ")).to contain_exactly("session=secret", "a_sid=from-a")
    end

    it "does not change the headers hash passed in" do
      headers = { "Cookie" => "session=secret" }
      redirect("https://api.example.com/start", "/landing", set_cookie: "a_sid=from-a")
      HTTParty::Request.new(Net::HTTP::Get, "https://api.example.com/start", headers: headers).perform
      expect(headers).to eq("Cookie" => "session=secret")
    end
  end
end
