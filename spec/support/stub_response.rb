module HTTParty
  module StubResponse
    def stub_http_response_with(filename)
      format = filename.split('.').last.intern
      data = file_fixture(filename)

      response = Net::HTTPOK.new("1.1", 200, "Content for you")
      response.stub!(:body).and_return(data)

      http_request = HTTParty::Request.new(Net::HTTP::Get, 'http://localhost', :format => format)
      http_request.stub_chain(:http, :request).and_return(response)

      HTTParty::Request.should_receive(:new).and_return(http_request)
    end

    def stub_chunked_http_response_with(chunks)
      response = Net::HTTPResponse.new("1.1", 200, nil)
      response.stub(:chunked_data).and_return(chunks)
      def response.read_body(&block)
        @body || chunked_data.each(&block)
      end

      http_request = HTTParty::Request.new(Net::HTTP::Get, 'http://localhost', :format => "html")
      http_request.stub_chain(:http, :request).and_yield(response).and_return(response)

      HTTParty::Request.should_receive(:new).and_return(http_request)
    end

    def stub_response(body, code = 200)
      @request.options[:base_uri] ||= 'http://localhost'
      unless defined?(@http) && @http
        @http = Net::HTTP.new('localhost', 80)
        @request.stub!(:http).and_return(@http)
      end

      response = Net::HTTPResponse::CODE_TO_OBJ[code.to_s].new("1.1", code, body)
      response.stub!(:body).and_return(body)

      @http.stub!(:request).and_return(response)
      response
    end
  end
end
