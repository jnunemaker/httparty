module HTTParty
  module Logger
    class ApacheLogger #:nodoc:
      TAG_NAME = HTTParty.name

      attr_accessor :level, :logger, :current_time

      def initialize(logger, level)
        @logger = logger
        @level  = level.to_sym
      end

      def format(request, response)
        @current_time  ||= Time.new.strftime("%Y-%m-%d %H:%M:%S.%L %z")
        http_method    = request.http_method.name.split("::").last.upcase
        path           = request.path.to_s
        content_length = response['Content-Length']

        print(response.code, content_length, http_method, path)
      end

      def print(code, content_length, http_method, path)
        @logger.send @level, "[#{TAG_NAME}] [#{@current_time}] #{code} \"#{http_method} #{path}\" #{content_length || "-"} "
      end
    end
  end
end
