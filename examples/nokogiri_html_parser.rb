require 'rubygems'
require 'nokogiri'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

class HtmlParserIncluded < HTTParty::Parser
  def html
    Nokogiri::HTML(body)
  end
end

class Page
  include HTTParty
  parser HtmlParserIncluded
end

pp Page.get('http://www.google.com')
