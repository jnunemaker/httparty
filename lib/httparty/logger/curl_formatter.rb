# frozen_string_literal: true

module HTTParty
  module Logger
    class CurlFormatter #:nodoc:
      TAG_NAME = HTTParty.name
      OUT      = '>'
      IN       = '<'

      attr_accessor :level, :logger

      def initialize(logger, level)
        @logger   = logger
        @level    = level.to_sym
        @messages = []
      end

      def format(request, response)
        @request  = request
        @response = response

        log_request
        log_response

        logger.public_send level, messages.join("\n")
      end

      private

      attr_reader :request, :response
      attr_accessor :messages

      def log_request
        log_url
        log_headers
        log_query
        log OUT, request.raw_body if request.raw_body
        log OUT
      end

      def log_response
        log IN, "HTTP/#{response.http_version} #{response.code}"
        log_response_headers
        log IN, "\n", response.body
        log IN
      end

      def log_url
        http_method = request.http_method.name.split('::').last.upcase
        uri = if request.options[:base_uri]
                request.options[:base_uri] + request.path.path
              else
                request.path.to_s
              end

        log OUT, http_method, ' ', uri
      end

      def log_headers
        return unless request.options[:headers] && request.options[:headers].size > 0

        log OUT, 'Headers: '
        log_hash request.options[:headers]
      end

      def log_query
        query = request.options[:query]
        return unless query

        log OUT, 'Query: '
        query.respond_to?(:to_hash) ? log_hash(query.to_hash) : log(OUT, query)
      end

      def log_response_headers
        headers = response.respond_to?(:headers) ? response.headers : response
        response.each_header do |response_header|
          log IN, response_header.capitalize, ': ', headers[response_header]
        end
      end

      def log_hash(hash)
        hash.each { |k, v| log(OUT, k, ': ', v) }
      end

      # Each part is converted before it is joined, so values in mixed
      # encodings can't raise and fail the request just to write a log line.
      def log(direction, *parts)
        line = parts.map { |part| encode_log(part) }.join
        messages << "[#{TAG_NAME}] [#{current_time}] #{direction} #{line}"
      end

      # Binary and broken UTF-8 are relabeled and scrubbed so readable text
      # survives; other charsets are converted.
      def encode_log(part)
        text = part.to_s
        return text if text.encoding == Encoding::UTF_8 && text.valid_encoding?

        if text.encoding == Encoding::BINARY || text.encoding == Encoding::UTF_8
          relabel_utf8(text)
        else
          text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      rescue Encoding::ConverterNotFoundError
        relabel_utf8(text)
      end

      def relabel_utf8(text)
        utf8 = text.dup.force_encoding(Encoding::UTF_8)
        utf8.valid_encoding? ? utf8 : utf8.scrub
      end

      def current_time
        Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
      end
    end
  end
end
