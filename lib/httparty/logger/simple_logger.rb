module HTTParty
  module Logger
    class SimpleLogger
      TAG_NAME = HTTParty.name

      attr_accessor :level, :logger

      def initialize(logger, level)
        @logger = logger
        @level = level.to_sym
      end

      def format(request, response)
        time = Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
        method = request.http_method.name.split("::").last.upcase
        @logger.send(@level, "[#{TAG_NAME}] [#{time}] #{method} #{request.uri} - #{response.code} - #{response.body}")
      end
    end
  end
end
