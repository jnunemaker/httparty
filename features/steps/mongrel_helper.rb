require 'base64'
class BasicMongrelHandler < Mongrel::HttpHandler
  attr_accessor :content_type, :custom_headers, :response_body, :response_code, :preprocessor, :username, :password

  def initialize
    @content_type = "text/html"
    @response_body = ""
    @response_code = 200
    @custom_headers = {}
  end

  def process(request, response)
    instance_eval(&preprocessor) if preprocessor
    reply_with(response, response_code, response_body)
  end

  def reply_with(response, code, response_body)
    response.start(code) do |head, body|
      head["Content-Type"] = content_type
      custom_headers.each { |k, v| head[k] = v }
      body.write(response_body)
    end
  end
end

class DeflateHandler < BasicMongrelHandler
  def process(request, response)
    response.start do |head, body|
      head['Content-Encoding'] = 'deflate'
      body.write Zlib::Deflate.deflate(response_body)
    end
  end
end

class GzipHandler < BasicMongrelHandler
  def process(request, response)
    response.start do |head, body|
      head['Content-Encoding'] = 'gzip'
      body.write gzip(response_body)
    end
  end

  protected

  def gzip(string)
    sio = StringIO.new('', 'r+')
    gz = Zlib::GzipWriter.new sio
    gz.write string
    gz.finish
    sio.rewind
    sio.read
  end
end

module BasicAuthentication
  def self.extended(base)
    base.custom_headers["WWW-Authenticate"] = 'Basic Realm="Super Secret Page"'
  end

  def process(request, response)
    if authorized?(request)
      super
    else
      reply_with(response, 401, "Incorrect.  You have 20 seconds to comply.")
    end
  end

  def authorized?(request)
    request.params["HTTP_AUTHORIZATION"] == "Basic " + Base64.encode64("#{@username}:#{@password}").strip
  end
end

module DigestAuthentication
  def self.extended(base)
    base.custom_headers["WWW-Authenticate"] = 'Digest realm="testrealm@host.com",qop="auth,auth-int",nonce="nonce",opaque="opaque"'
  end

  def process(request, response)
    if authorized?(request)
      super
    else
      reply_with(response, 401, "Incorrect.  You have 20 seconds to comply.")
    end
  end

  def authorized?(request)
    request.params["HTTP_AUTHORIZATION"] =~ /Digest.*uri=/
  end
end

module DigestAuthenticationUsingMD5Sess
  NONCE = 'nonce'
  REALM = 'testrealm@host.com'
  QOP = 'auth,auth-int'
  def self.extended(base)
    base.custom_headers["WWW-Authenticate"] = %(Digest realm="#{REALM}",qop="#{QOP}",algorithm="MD5-sess",nonce="#{NONCE}",opaque="opaque"')
  end

  def process(request, response)
    if authorized?(request)
      super
    else
      reply_with(response, 401, "Incorrect.  You have 20 seconds to comply.")
    end
  end

  def md5(str)
    Digest::MD5.hexdigest(str)
  end

  def authorized?(request)
    auth = request.params["HTTP_AUTHORIZATION"]
    params = {}
    auth.to_s.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }.gsub(/(\w+)=([^,]*)/) { params[$1] = $2 }
    a1a = [@username,REALM,@password].join(':')
    a1 = [md5(a1a),NONCE,params['cnonce'] ].join(':')
    a2 = [ request.params["REQUEST_METHOD"], request.params["REQUEST_URI"] ] .join(':')
    expected_response = md5( [md5(a1), NONCE, params['nc'], params['cnonce'], QOP, md5(a2)].join(':') )
    expected_response == params['response']
  end
end


def new_mongrel_redirector(target_url, relative_path = false)
  target_url = "http://#{@host_and_port}#{target_url}" unless relative_path
  Mongrel::RedirectHandler.new(target_url)
end
