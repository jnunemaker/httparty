require 'httparty/logger/apache_logger'
require 'httparty/logger/curl_logger'

module HTTParty
  module Logger
    def self.formatters
      @formatters ||= {
        :curl => Logger::CurlLogger,
        :apache => Logger::ApacheLogger
      }
    end

    def self.add_formatters custom_formatters
      formatters.merge! custom_formatters
    end

    def self.build(logger, level, formatter)
      level ||= :info
      formatter ||= :apache

      logger_klass = formatters[formatter] || Logger::ApacheLogger
      logger_klass.new(logger, level)
    end
  end
end
