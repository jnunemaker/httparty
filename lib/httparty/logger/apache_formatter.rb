# frozen_string_literal: true

module HTTParty
  module Logger
    class ApacheFormatter #:nodoc:
      TAG_NAME = HTTParty.name
      LOG_ESCAPES = /[[:cntrl:]"\\]/

      attr_accessor :level, :logger

      def initialize(logger, level)
        @logger = logger
        @level  = level.to_sym
      end

      def format(request, response)
        @request = request
        @response = response

        logger.public_send level, message
      end

      private

      attr_reader :request, :response

      def message
        "[#{TAG_NAME}] [#{current_time}] #{response.code} \"#{http_method} #{sanitize(path)}\" #{content_length || '-'} "
      end

      def current_time
        Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
      end

      def http_method
        request.http_method.name.split('::').last.upcase
      end

      def path
        request.path.to_s
      end

      # Escape the request path the way Apache's own access log does: control
      # characters (e.g. CR/LF) become \xhh, and " and \ get a backslash. A
      # crafted path then can't split or forge a log line (CWE-117), and the
      # attempt stays visible. This matters with a permissive URI adapter
      # such as Addressable; the default URI adapter rejects these characters.
      # Invalid bytes are scrubbed first so the regex can't raise.
      def sanitize(value)
        value.to_s.scrub.gsub(LOG_ESCAPES) do |char|
          char == '"' || char == '\\' ? "\\#{char}" : '\\x%02x' % char.ord
        end
      end

      def content_length
        response.respond_to?(:headers) ? response.headers['Content-Length'] : response['Content-Length']
      end
    end
  end
end
