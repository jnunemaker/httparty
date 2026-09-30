module HTTParty
  module StubResponse
    def stub_http_response_with(filename)
      format = filename.split('.').last.intern
      data = file_fixture(filename)

      response = Net::HTTPOK.new("1.1", 200, "Content for you")
      allow(response).to receive(:body).and_return(data)

      http_request = HTTParty::Request.new(Net::HTTP::Get, 'http://localhost', format: format)
      connection = double('connection', request: response)
      http_request.options[:connection_adapter] = ->(_uri, _options) { connection }

      expect(HTTParty::Request).to receive(:new).and_return(http_request)
    end

    def stub_chunked_http_response_with(chunks, options = {format: "html"})
      response = Net::HTTPResponse.new("1.1", 200, nil)
      allow(response).to receive(:chunked_data).and_return(chunks)
      def response.read_body(&block)
        @body || chunked_data.each(&block)
      end
      yield(response) if block_given?

      http_request = HTTParty::Request.new(Net::HTTP::Get, 'http://localhost', options)
      connection = double('connection')
      allow(connection).to receive(:request).and_yield(response).and_return(response)
      http_request.options[:connection_adapter] = ->(_uri, _options) { connection }

      expect(HTTParty::Request).to receive(:new).and_return(http_request)
    end

    def stub_response(body, code = '200')
      code = code.to_s
      # Only set default base_uri if path is relative (has no host)
      # This avoids triggering URI safety validation for absolute URLs in tests
      @request.options[:base_uri] ||= 'http://localhost' if @request.path.relative?
      unless defined?(@http) && @http
        @http = Net::HTTP.new('localhost', 80)
        @request.options[:connection_adapter] = ->(_uri, _options) { @http }
      end

      # CODE_TO_OBJ currently missing 308
      if code == '308'
        response = Net::HTTPRedirection.new("1.1", code, body)
      else
        response = Net::HTTPResponse::CODE_TO_OBJ[code].new("1.1", code, body)
      end
      allow(response).to receive(:body).and_return(body)

      allow(@http).to receive(:request).and_return(response)
      response
    end
  end
end
