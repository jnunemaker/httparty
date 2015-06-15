module HTTParty
  module Logger
    class CurlFormatter #:nodoc:
      TAG_NAME = HTTParty.name
      OUT = ">"
      IN = "<"

      attr_accessor :level, :logger, :current_time

      def initialize(logger, level)
        @logger = logger
        @level  = level.to_sym
      end

      def format(request, response)
        messages        = []
        time            = Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
        http_method     = request.http_method.name.split("::").last.upcase
        path            = request.path.to_s

        messages << print(time, OUT, "#{http_method} #{path}")

        if request.options[:headers] && request.options[:headers].size > 0
          request.options[:headers].each do |k, v|
            messages << print(time, OUT, "#{k}: #{v}")
          end
        end

        messages << print(time, OUT, request.raw_body)
        messages << print(time, OUT, "")
        messages << print(time, IN, "HTTP/#{response.http_version} #{response.code}")

        headers = response.respond_to?(:headers) ? response.headers : response
        response.each_header do |response_header|
          messages << print(time, IN, "#{response_header.capitalize}: #{headers[response_header]}")
        end

        messages << print(time, IN, "\n#{response.body}")

        @logger.send @level, messages.join("\n")
      end

      def print(time, direction, line)
        "[#{TAG_NAME}] [#{time}] #{direction} #{line}"
      end
    end
  end
end
