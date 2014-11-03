require 'httparty/logger/apache_logger'
require 'httparty/logger/curl_logger'
require 'httparty/logger/simple_logger'

module HTTParty
  module Logger
    def self.build(logger, level, formatter)
      level  ||= :info
      formatter ||= :apache

      case formatter
      when :curl
        Logger::CurlLogger.new(logger, level)
      when :simple
        Logger::SimpleLogger.new(logger, level)
      else
        Logger::ApacheLogger.new(logger, level)
      end
    end
  end
end
