# frozen_string_literal: true

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

      authenticator.authorization_header.each do |v|
        add_field('Authorization', v)
      end

      authenticator.cookie_header.each do |v|
        add_field('Cookie', v)
      end
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
          %(Digest username="#{@username}"),
          %(realm="#{@response['realm']}"),
          %(nonce="#{@response['nonce']}"),
          %(uri="#{@path}"),
          %(response="#{request_digest}")
        ]

        header << %(algorithm="#{@response['algorithm']}") if algorithm_present?

        if qop_present?
          header << %(cnonce="#{@cnonce}")
          header << %(qop="#{@response['qop']}")
          header << 'nc=00000001'
        end

        header << %(opaque="#{@response['opaque']}") if opaque_present?
        header
      end

      def cookie_header
        @cookies
      end

      private

      def parse(response_header)
        header = response_header['www-authenticate']

        header = header.gsub(/qop=(auth(?:-int)?)/, 'qop="\\1"')

        header =~ /Digest (.*)/
        params = {}
        if $1
          non_quoted = $1.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }
          non_quoted.gsub(/(\w+)=([^,]*)/) { params[$1] = $2 }
        end
        # The server can offer a list, but the client has to answer with one.
        params['qop'] = 'auth' if params['qop'].to_s.split(',').map(&:strip).include?('auth')
        params
      end

      # Send back each cookie's name=value only. Attributes like Path and
      # HttpOnly are for the client, and cookies share one header, split by "; ".
      def parse_cookies(response_header)
        set_cookies = response_header.respond_to?(:get_fields) ? response_header.get_fields('Set-Cookie') : response_header['Set-Cookie']
        cookies = Array(set_cookies).map { |cookie| cookie.split(';', 2).first.to_s.strip }.reject(&:empty?)
        cookies.empty? ? [] : [cookies.join('; ')]
      end

      def opaque_present?
        @response.key?('opaque') && !@response['opaque'].empty?
      end

      def qop_present?
        @response.key?('qop') && !@response['qop'].empty?
      end

      def random
        format '%x', (Time.now.to_i + rand(65535))
      end

      def request_digest
        a = [md5(a1), @response['nonce'], md5(a2)]
        a.insert(2, '00000001', @cnonce, @response['qop']) if qop_present?
        md5(a.join(':'))
      end

      def md5(str)
        Digest::MD5.hexdigest(str)
      end

      def algorithm_present?
        @response.key?('algorithm') && !@response['algorithm'].empty?
      end

      def use_md5_sess?
        algorithm_present? && @response['algorithm'] == 'MD5-sess'
      end

      def a1
        a1_user_realm_pwd =  [@username, @response['realm'], @password].join(':')
        if use_md5_sess?
          [ md5(a1_user_realm_pwd), @response['nonce'], @cnonce ].join(':')
        else
          a1_user_realm_pwd
        end
      end

      def a2
        [@method, @path].join(':')
      end
    end
  end
end
