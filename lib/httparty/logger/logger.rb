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

    def self.add_formatter(name, formatter)
      raise HTTParty::Error.new("Log Formatter with name #{name} already exists") if formatters.include?(name)
      formatters.merge!(name.to_sym => formatter)
    end

    def self.build(logger, level, formatter)
      level ||= :info
      formatter ||= :apache

      logger_klass = formatters[formatter] || Logger::ApacheLogger
      logger_klass.new(logger, level)
    end
  end
end
