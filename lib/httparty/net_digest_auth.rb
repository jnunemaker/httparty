require 'digest/md5'
require 'net/http'

module Net
  module HTTPHeader
    def digest_auth(username, password, response)
      authenticator = DigestAuthenticator.new(
        username,
        password,
        @method,
        @path,
        response
      )

      @header['Authorization'] = authenticator.authorization_header
      @header['cookie'] = append_cookies(authenticator) if response['Set-Cookie']
    end

    def append_cookies(authenticator)
      cookies = @header['cookie'] ? @header['cookie'] : []
      cookies.concat(authenticator.cookie_header)
    end

    class DigestAuthenticator
      def initialize(username, password, method, path, response_header)
        @username = username
        @password = password
        @method   = method
        @path     = path
        @response = parse(response_header)
        @cookies  = parse_cookies(response_header)
      end

      def authorization_header
        @cnonce = md5(random)
        header = [
          %Q(Digest username="#{@username}"),
          %Q(realm="#{@response['realm']}"),
          %Q(nonce="#{@response['nonce']}"),
          %Q(uri="#{@path}"),
          %Q(response="#{request_digest}")
        ]

        if qop_present?
          fields = [
            %Q(cnonce="#{@cnonce}"),
            %Q(qop="#{@response['qop']}"),
            "nc=00000001"
          ]
          fields.each { |field| header << field }
        end

        header << %Q(opaque="#{@response['opaque']}") if opaque_present?
        header
      end

      def cookie_header
        @cookies
      end

    private

      def parse(response_header)
        header = response_header['www-authenticate']
          .gsub(/qop=(auth(?:-int)?)/, 'qop="\\1"')

        header =~ /Digest (.*)/
        params = {}
        $1.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }
        params
      end

      def parse_cookies(response_header)
        return [] unless response_header['Set-Cookie']

        cookies = response_header['Set-Cookie'].split('; ')

        cookies.reduce([]) do |ret, cookie|
          ret << cookie
          ret
        end

        cookies
      end

      def opaque_present?
        @response.has_key?('opaque') and not @response['opaque'].empty?
      end

      def qop_present?
        @response.has_key?('qop') and not @response['qop'].empty?
      end

      def random
        "%x" % (Time.now.to_i + rand(65535))
      end

      def request_digest
        a = [md5(a1), @response['nonce'], md5(a2)]
        a.insert(2, "00000001", @cnonce, @response['qop']) if qop_present?
        md5(a.join(":"))
      end

      def md5(str)
        Digest::MD5.hexdigest(str)
      end

      def a1
        [@username, @response['realm'], @password].join(":")
      end

      def a2
        [@method, @path].join(":")
      end
    end
  end
end
