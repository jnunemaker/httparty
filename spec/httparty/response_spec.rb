require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe HTTParty::Response do
  before do
    @last_modified = Date.new(2010, 1, 15).to_s
    @content_length = '1024'
    @request_object = HTTParty::Request.new Net::HTTP::Get, '/'
    @response_object = Net::HTTPOK.new('1.1', 200, 'OK')
    allow(@response_object).to receive_messages(body: "{foo:'bar'}")
    @response_object['last-modified'] = @last_modified
    @response_object['content-length'] = @content_length
    @parsed_response = lambda { {"foo" => "bar"} }
    @response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
  end

  describe ".underscore" do
    it "works with one capitalized word" do
      expect(HTTParty::Response.underscore("Accepted")).to eq("accepted")
    end

    it "works with titlecase" do
      expect(HTTParty::Response.underscore("BadGateway")).to eq("bad_gateway")
    end

    it "works with all caps" do
      expect(HTTParty::Response.underscore("OK")).to eq("ok")
    end
  end

  describe "initialization" do
    it "should set the Net::HTTP Response" do
      expect(@response.response).to eq(@response_object)
    end

    it "should set body" do
      expect(@response.body).to eq(@response_object.body)
    end

    it "should set code" do
      expect(@response.code).to eq(@response_object.code)
    end

    it "should set code as a Fixnum" do
      expect(@response.code).to be_an_instance_of(Fixnum)
    end

    context 'when raise_on is supplied' do
      let(:request) { HTTParty::Request.new(Net::HTTP::Get, '/', raise_on: [404]) }

      context "and response's status code is in range" do
        let(:body)     { 'Not Found' }
        let(:response) { Net::HTTPNotFound.new('1.1', 404, body) }

        before do
          allow(response).to receive(:body).and_return(body)
        end

        subject { described_class.new(request, response, @parsed_response) }

        it 'throws exception' do
          expect{ subject }.to raise_error(HTTParty::ResponseError, "Code 404 - #{body}")
        end
      end

      context "and response's status code is not in range" do
        subject { described_class.new(request, @response_object, @parsed_response) }

        it 'does not throw exception' do
          expect{ subject }.not_to raise_error(HTTParty::ResponseError)
        end
      end
    end
  end

  it "returns response headers" do
    expect(@response.headers).to eq({'last-modified' => [@last_modified], 'content-length' => [@content_length]})
  end

  it "should send missing methods to delegate" do
    expect(@response['foo']).to eq('bar')
  end

  it "response to request" do
    expect(@response.respond_to?(:request)).to be_truthy
  end

  it "responds to response" do
    expect(@response.respond_to?(:response)).to be_truthy
  end

  it "responds to body" do
    expect(@response.respond_to?(:body)).to be_truthy
  end

  it "responds to headers" do
    expect(@response.respond_to?(:headers)).to be_truthy
  end

  it "responds to parsed_response" do
    expect(@response.respond_to?(:parsed_response)).to be_truthy
  end

  it "responds to predicates" do
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    expect(response.respond_to?(:success?)).to be_truthy
  end

  it "responds to anything parsed_response responds to" do
    expect(@response.respond_to?(:[])).to be_truthy
  end

  it "should be able to iterate if it is array" do
    response = HTTParty::Response.new(@request_object, @response_object, lambda { [{'foo' => 'bar'}, {'foo' => 'baz'}] })
    expect(response.size).to eq(2)
    expect {
      response.each { |item| }
    }.to_not raise_error
  end

  it "allows headers to be accessed by mixed-case names in hash notation" do
    expect(@response.headers['Content-LENGTH']).to eq(@content_length)
  end

  it "returns a comma-delimited value when multiple values exist" do
    @response_object.add_field 'set-cookie', 'csrf_id=12345; path=/'
    @response_object.add_field 'set-cookie', '_github_ses=A123CdE; path=/'
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    expect(response.headers['set-cookie']).to eq("csrf_id=12345; path=/, _github_ses=A123CdE; path=/")
  end

  # Backwards-compatibility - previously, #headers returned a Hash
  it "responds to hash methods" do
    hash_methods = {}.methods - @response.headers.methods
    hash_methods.each do |method_name|
      expect(@response.headers.respond_to?(method_name)).to be_truthy
    end
  end

  describe "#tap" do
    it "is possible to tap into a response" do
      result = @response.tap(&:code)

      expect(result).to eq @response
    end
  end

  describe "#inspect" do

    it "works" do
      inspect = @response.inspect
      expect(inspect).to include("HTTParty::Response:0x")
      expect(inspect).to include("parsed_response={\"foo\"=>\"bar\"}")
      expect(inspect).to include("@response=#<Net::HTTPOK 200 OK readbody=false>")
      expect(inspect).to include("@headers={")
      expect(inspect).to include("last-modified")
      expect(inspect).to include("content-length")
    end
  end

  describe '#is_a?' do
    # it response.ancestors.inspect do
    it 'returns true when the obj is a HTTParty::Response object' do
      # puts "\n\n\n\n\n\n", response.ancestors, "\n\n\n\n\n\n"
      expect(@response.is_a?(@response.class)).to be true
    end
  end

  describe "#is_a?" do
    subject { HTTParty::Response.new(@request_object, @response_object, @parsed_response) }

    it { is_expected.to respond_to(:is_a?).with(1).arguments }
    it { expect(subject.is_a?(HTTParty::Response)).to be_truthy }
    it { expect(subject.is_a?(BasicObject)).to be_truthy }
    it { expect(subject.is_a?(Object)).to be_falsey }
  end

  describe "#kind_of?" do
    subject { HTTParty::Response.new(@request_object, @response_object, @parsed_response) }

    it { is_expected.to respond_to(:kind_of?).with(1).arguments }
    it { expect(subject.kind_of?(HTTParty::Response)).to be_truthy }
    it { expect(subject.kind_of?(BasicObject)).to be_truthy }
    it { expect(subject.kind_of?(Object)).to be_falsey }
  end

  describe "semantic methods for response codes" do
    def response_mock(klass)
      response = klass.new('', '', '')
      allow(response).to receive(:body)
      response
    end

    context "major codes" do
      it "is information" do
        net_response = response_mock(Net::HTTPInformation)
        response = HTTParty::Response.new(@request_object, net_response, '')
        expect(response.information?).to be_truthy
      end

      it "is success" do
        net_response = response_mock(Net::HTTPSuccess)
        response = HTTParty::Response.new(@request_object, net_response, '')
        expect(response.success?).to be_truthy
      end

      it "is redirection" do
        net_response = response_mock(Net::HTTPRedirection)
        response = HTTParty::Response.new(@request_object, net_response, '')
        expect(response.redirection?).to be_truthy
      end

      it "is client error" do
        net_response = response_mock(Net::HTTPClientError)
        response = HTTParty::Response.new(@request_object, net_response, '')
        expect(response.client_error?).to be_truthy
      end

      it "is server error" do
        net_response = response_mock(Net::HTTPServerError)
        response = HTTParty::Response.new(@request_object, net_response, '')
        expect(response.server_error?).to be_truthy
      end
    end

    context "for specific codes" do
      SPECIFIC_CODES = {
        accepted?:                        Net::HTTPAccepted,
        bad_gateway?:                     Net::HTTPBadGateway,
        bad_request?:                     Net::HTTPBadRequest,
        conflict?:                        Net::HTTPConflict,
        continue?:                        Net::HTTPContinue,
        created?:                         Net::HTTPCreated,
        expectation_failed?:              Net::HTTPExpectationFailed,
        forbidden?:                       Net::HTTPForbidden,
        found?:                           Net::HTTPFound,
        gateway_time_out?:                Net::HTTPGatewayTimeOut,
        gone?:                            Net::HTTPGone,
        internal_server_error?:           Net::HTTPInternalServerError,
        length_required?:                 Net::HTTPLengthRequired,
        method_not_allowed?:              Net::HTTPMethodNotAllowed,
        moved_permanently?:               Net::HTTPMovedPermanently,
        multiple_choice?:                 Net::HTTPMultipleChoice,
        no_content?:                      Net::HTTPNoContent,
        non_authoritative_information?:   Net::HTTPNonAuthoritativeInformation,
        not_acceptable?:                  Net::HTTPNotAcceptable,
        not_found?:                       Net::HTTPNotFound,
        not_implemented?:                 Net::HTTPNotImplemented,
        not_modified?:                    Net::HTTPNotModified,
        ok?:                              Net::HTTPOK,
        partial_content?:                 Net::HTTPPartialContent,
        payment_required?:                Net::HTTPPaymentRequired,
        precondition_failed?:             Net::HTTPPreconditionFailed,
        proxy_authentication_required?:   Net::HTTPProxyAuthenticationRequired,
        request_entity_too_large?:        Net::HTTPRequestEntityTooLarge,
        request_time_out?:                Net::HTTPRequestTimeOut,
        request_uri_too_long?:            Net::HTTPRequestURITooLong,
        requested_range_not_satisfiable?: Net::HTTPRequestedRangeNotSatisfiable,
        reset_content?:                   Net::HTTPResetContent,
        see_other?:                       Net::HTTPSeeOther,
        service_unavailable?:             Net::HTTPServiceUnavailable,
        switch_protocol?:                 Net::HTTPSwitchProtocol,
        temporary_redirect?:              Net::HTTPTemporaryRedirect,
        unauthorized?:                    Net::HTTPUnauthorized,
        unsupported_media_type?:          Net::HTTPUnsupportedMediaType,
        use_proxy?:                       Net::HTTPUseProxy,
        version_not_supported?:           Net::HTTPVersionNotSupported
      }

      # Ruby 2.0, new name for this response.
      if RUBY_VERSION >= "2.0.0" && ::RUBY_PLATFORM != "java"
        SPECIFIC_CODES[:multiple_choices?] = Net::HTTPMultipleChoices
      end

      SPECIFIC_CODES.each do |method, klass|
        it "responds to #{method}" do
          net_response = response_mock(klass)
          response = HTTParty::Response.new(@request_object, net_response, '')
          expect(response.__send__(method)).to be_truthy
        end
      end
    end
  end

  describe "headers" do
    it "can initialize without headers" do
      headers = HTTParty::Response::Headers.new
      expect(headers).to eq({})
    end
  end
end
