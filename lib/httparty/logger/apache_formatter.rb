module HTTParty
  module Logger
    class ApacheFormatter #:nodoc:
      TAG_NAME = HTTParty.name

      attr_accessor :level, :logger, :current_time

      def initialize(logger, level)
        @logger = logger
        @level  = level.to_sym
      end

      def format(request, response)
        current_time   = Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
        http_method    = request.http_method.name.split("::").last.upcase
        path           = request.path.to_s
        content_length = response.respond_to?(:headers) ? response.headers['Content-Length'] : response['Content-Length']
        @logger.send @level, "[#{TAG_NAME}] [#{current_time}] #{response.code} \"#{http_method} #{path}\" #{content_length || '-'} "
      end
    end
  end
end
