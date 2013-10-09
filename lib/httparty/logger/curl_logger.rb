module HTTParty
  module Logger
    class CurlLogger #:nodoc:
      TAG_NAME = HTTParty.name

      attr_accessor :level, :logger, :current_time

      def initialize(logger, level)
        @logger = logger
        @level  = level.to_sym
      end

      def format(request, response)
        @messages       = []
        @current_time   = Time.new.strftime("%Y-%m-%d %H:%M:%S %z")
        http_method     = request.http_method.name.split("::").last.upcase
        path            = request.path.to_s

        print_outgoing "#{http_method} #{path}"
        if request.options[:headers] && request.options[:headers].size > 0
          request.options[:headers].each do |k, v|
            print_outgoing "#{k}: #{v}"
          end
        end

        print_outgoing request.raw_body
        print_outgoing ""
        print_incoming "HTTP/#{response.http_version} #{response.code}"

        headers = response.respond_to?(:headers) ? response.headers : response
        response.each_header do |response_header|
          print_incoming "#{response_header.capitalize}: #{headers[response_header]}"
        end

        print_incoming "\n#{response.body}"

        @logger.send @level, @messages.join("\n")
      end

      def print_outgoing(line)
        @messages << print(">", line)
      end

      def print_incoming(line)
        @messages << print("<", line)
      end

      def print(direction, line)
        "[#{TAG_NAME}] [#{@current_time}] #{direction} #{line}"
      end
    end
  end
end
