require 'digest/md5'
require 'net/http'

module Net
  module HTTPHeader
    def digest_auth(username, password, response)
      @header['Authorization'] = DigestAuthenticator.new(username, password,
          @method, @path, response).authorization_header
    end


    class DigestAuthenticator
      def initialize(username, password, method, path, response_header)
        @username = username
        @password = password
        @method   = method
        @path     = path
        @response = parse(response_header)
      end

      def authorization_header
        @cnonce = md5(random)
        header = [
          %Q(Digest username="#{@username}"),
          %Q(realm="#{@response['realm']}"),
          %Q(nonce="#{@response['nonce']}"),
          %Q(uri="#{@path}"),
          %Q(response="#{request_digest}"),
        ]

        if qop_present?
          fields = [
            %Q(cnonce="#{@cnonce}"),
            %Q(qop="#{@response['qop']}"),
            %Q(nc=00000001)
          ]
          fields.each { |field| header << field }
        end

        header << %Q(opaque="#{@response['opaque']}") if opaque_present?
        header
      end

    private

      def parse(response_header)
        response_header['www-authenticate'] =~ /Digest (.*)/
        params = {}
        $1.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }
        params
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
