def basic_mongrel_handler
  Class.new(Mongrel::HttpHandler) do
    attr_writer :content_type, :response_body, :response_code, :preprocessor

    def initialize
      @content_type = "text/html"
      @response_body = ""
      @response_code = 200
      @custom_headers = {}
    end

    def process(request, response)
      instance_eval &@preprocessor if @preprocessor
      reply_with(response, @response_code, @response_body)
    end

    def reply_with(response, code, response_body)
      response.start(code) do |head, body|
        head["Content-Type"] = @content_type
        @custom_headers.each { |k,v| head[k] = v }
        body.write(response_body)
      end
    end
  end
end

def new_mongrel_handler
  basic_mongrel_handler.new
end

def add_basic_authentication_to(handler)
  m = Module.new do
    attr_writer :username, :password

    def self.extended(base)
      base.instance_eval { @custom_headers["WWW-Authenticate"] = 'Basic Realm="Super Secret Page"' }
      base.class_eval { alias_method_chain :process, :basic_authentication }
    end

    def process_with_basic_authentication(request, response)
      if authorized?(request) then process_without_basic_authentication(request, response)
      else reply_with(response, 401, "Incorrect.  You have 20 seconds to comply.")
      end
    end

    def authorized?(request)
      request.params["HTTP_AUTHORIZATION"] == "Basic " + Base64.encode64("#{@username}:#{@password}").strip
    end
  end
  handler.extend(m)
end

def new_mongrel_redirector(target_url, relative_path = false)
  target_url = "http://#{@host_and_port}#{target_url}" unless relative_path
  Mongrel::RedirectHandler.new(target_url)
end
