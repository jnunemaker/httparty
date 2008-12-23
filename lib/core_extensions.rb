# Copyright (c) 2008 Sam Smoot.
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Object
  # @return <TrueClass, FalseClass>
  #
  # @example [].blank?         #=>  true
  # @example [1].blank?        #=>  false
  # @example [nil].blank?      #=>  false
  # 
  # Returns true if the object is nil or empty (if applicable)
  def blank?
    nil? || (respond_to?(:empty?) && empty?)
  end
end # class Object

class Numeric
  # @return <TrueClass, FalseClass>
  # 
  # Numerics can't be blank
  def blank?
    false
  end
end # class Numeric

class NilClass
  # @return <TrueClass, FalseClass>
  # 
  # Nils are always blank
  def blank?
    true
  end
end # class NilClass

class TrueClass
  # @return <TrueClass, FalseClass>
  # 
  # True is not blank.  
  def blank?
    false
  end
end # class TrueClass

class FalseClass
  # False is always blank.
  def blank?
    true
  end
end # class FalseClass

class String
  # @example "".blank?         #=>  true
  # @example "     ".blank?    #=>  true
  # @example " hey ho ".blank? #=>  false
  # 
  # @return <TrueClass, FalseClass>
  # 
  # Strips out whitespace then tests if the string is empty.
  def blank?
    strip.empty?
  end
end # class String

require 'rexml/parsers/streamparser'
require 'rexml/parsers/baseparser'
require 'rexml/light/node'

# This is a slighly modified version of the XMLUtilityNode from
# http://merb.devjavu.com/projects/merb/ticket/95 (has.sox@gmail.com)
# It's mainly just adding vowels, as I ht cd wth n vwls :)
# This represents the hard part of the work, all I did was change the
# underlying parser.
class REXMLUtilityNode
  attr_accessor :name, :attributes, :children, :type
  
  def self.typecasts
    @@typecasts
  end
  
  def self.typecasts=(obj)
    @@typecasts = obj
  end
  
  def self.available_typecasts
    @@available_typecasts
  end
  
  def self.available_typecasts=(obj)
    @@available_typecasts = obj
  end

  self.typecasts = {}
  self.typecasts["integer"]       = lambda{|v| v.nil? ? nil : v.to_i}
  self.typecasts["boolean"]       = lambda{|v| v.nil? ? nil : (v.strip != "false")}
  self.typecasts["datetime"]      = lambda{|v| v.nil? ? nil : Time.parse(v).utc}
  self.typecasts["date"]          = lambda{|v| v.nil? ? nil : Date.parse(v)}
  self.typecasts["dateTime"]      = lambda{|v| v.nil? ? nil : Time.parse(v).utc}
  self.typecasts["decimal"]       = lambda{|v| BigDecimal(v)}
  self.typecasts["double"]        = lambda{|v| v.nil? ? nil : v.to_f}
  self.typecasts["float"]         = lambda{|v| v.nil? ? nil : v.to_f}
  self.typecasts["symbol"]        = lambda{|v| v.to_sym}
  self.typecasts["string"]        = lambda{|v| v.to_s}
  self.typecasts["yaml"]          = lambda{|v| v.nil? ? nil : YAML.load(v)}
  self.typecasts["base64Binary"]  = lambda{|v| v.unpack('m').first }

  self.available_typecasts = self.typecasts.keys

  def initialize(name, attributes = {})
    @name         = name.tr("-", "_")
    # leave the type alone if we don't know what it is
    @type         = self.class.available_typecasts.include?(attributes["type"]) ? attributes.delete("type") : attributes["type"]

    @nil_element  = attributes.delete("nil") == "true"
    @attributes   = undasherize_keys(attributes)
    @children     = []
    @text         = false
  end

  def add_node(node)
    @text = true if node.is_a? String
    @children << node
  end

  def to_hash
    if @type == "file"
      f = StringIO.new((@children.first || '').unpack('m').first)
      class << f
        attr_accessor :original_filename, :content_type
      end
      f.original_filename = attributes['name'] || 'untitled'
      f.content_type = attributes['content_type'] || 'application/octet-stream'
      return {name => f}
    end

    if @text
      return { name => typecast_value( translate_xml_entities( inner_html ) ) }
    else
      #change repeating groups into an array
      groups = @children.inject({}) { |s,e| (s[e.name] ||= []) << e; s }

      out = nil
      if @type == "array"
        out = []
        groups.each do |k, v|
          if v.size == 1
            out << v.first.to_hash.entries.first.last
          else
            out << v.map{|e| e.to_hash[k]}
          end
        end
        out = out.flatten

      else # If Hash
        out = {}
        groups.each do |k,v|
          if v.size == 1
            out.merge!(v.first)
          else
            out.merge!( k => v.map{|e| e.to_hash[k]})
          end
        end
        out.merge! attributes unless attributes.empty?
        out = out.empty? ? nil : out
      end

      if @type && out.nil?
        { name => typecast_value(out) }
      else
        { name => out }
      end
    end
  end

  # Typecasts a value based upon its type. For instance, if
  # +node+ has #type == "integer",
  # {{[node.typecast_value("12") #=> 12]}}
  #
  # @param value<String> The value that is being typecast.
  #
  # @details [:type options]
  #   "integer"::
  #     converts +value+ to an integer with #to_i
  #   "boolean"::
  #     checks whether +value+, after removing spaces, is the literal
  #     "true"
  #   "datetime"::
  #     Parses +value+ using Time.parse, and returns a UTC Time
  #   "date"::
  #     Parses +value+ using Date.parse
  #
  # @return <Integer, TrueClass, FalseClass, Time, Date, Object>
  #   The result of typecasting +value+.
  #
  # @note
  #   If +self+ does not have a "type" key, or if it's not one of the
  #   options specified above, the raw +value+ will be returned.
  def typecast_value(value)
    return value unless @type
    proc = self.class.typecasts[@type]
    proc.nil? ? value : proc.call(value)
  end

  # Convert basic XML entities into their literal values.
  #
  # @param value<#gsub> An XML fragment.
  #
  # @return <#gsub> The XML fragment after converting entities.
  def translate_xml_entities(value)
    value.gsub(/&lt;/,   "<").
          gsub(/&gt;/,   ">").
          gsub(/&quot;/, '"').
          gsub(/&apos;/, "'").
          gsub(/&amp;/,  "&")
  end

  # Take keys of the form foo-bar and convert them to foo_bar
  def undasherize_keys(params)
    params.keys.each do |key, value|
      params[key.tr("-", "_")] = params.delete(key)
    end
    params
  end

  # Get the inner_html of the REXML node.
  def inner_html
    @children.join
  end

  # Converts the node into a readable HTML node.
  #
  # @return <String> The HTML node in text form.
  def to_html
    attributes.merge!(:type => @type ) if @type
    "<#{name}#{attributes.to_xml_attributes}>#{@nil_element ? '' : inner_html}</#{name}>"
  end

  # @alias #to_html #to_s
  def to_s
    to_html
  end
end

class ToHashParser
  def self.from_xml(xml)
    stack = []
    parser = REXML::Parsers::BaseParser.new(xml)

    while true
      event = parser.pull
      case event[0]
      when :end_document
        break
      when :end_doctype, :start_doctype
        # do nothing
      when :start_element
        stack.push REXMLUtilityNode.new(event[1], event[2])
      when :end_element
        if stack.size > 1
          temp = stack.pop
          stack.last.add_node(temp)
        end
      when :text, :cdata
        stack.last.add_node(event[1]) unless event[1].strip.length == 0
      end
    end
    stack.pop.to_hash
  end
end

class Hash  
  # @return <String> This hash as a query string
  #
  # @example
  #   { :name => "Bob",
  #     :address => {
  #       :street => '111 Ruby Ave.',
  #       :city => 'Ruby Central',
  #       :phones => ['111-111-1111', '222-222-2222']
  #     }
  #   }.to_params
  #     #=> "name=Bob&address[city]=Ruby Central&address[phones][]=111-111-1111&address[phones][]=222-222-2222&address[street]=111 Ruby Ave."
  def to_params
    params = self.map { |k,v| normalize_param(k,v) }.join
    params.chop! # trailing &
    params
  end

  # @param key<Object> The key for the param.
  # @param value<Object> The value for the param.
  #
  # @return <String> This key value pair as a param
  #
  # @example normalize_param(:name, "Bob") #=> "name=Bob&"
  def normalize_param(key, value)
    param = ''
    stack = []

    if value.is_a?(Array)
      param << value.map { |element| normalize_param("#{key}[]", element) }.join
    elsif value.is_a?(Hash)
      stack << [key,value]
    else
      param << "#{key}=#{URI.encode(value.to_s)}&"
    end

    stack.each do |parent, hash|
      hash.each do |key, value|
        if value.is_a?(Hash)
          stack << ["#{parent}[#{key}]", value]
        else
          param << normalize_param("#{parent}[#{key}]", value)
        end
      end
    end

    param
  end
  
  # @return <String> The hash as attributes for an XML tag.
  #
  # @example
  #   { :one => 1, "two"=>"TWO" }.to_xml_attributes
  #     #=> 'one="1" two="TWO"'
  def to_xml_attributes
    map do |k,v|
      %{#{k.to_s.snake_case.sub(/^(.{1,1})/) { |m| m.downcase }}="#{v}"}
    end.join(' ')
  end
end