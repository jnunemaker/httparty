module Web
  module Entities
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def format(f)
        return @format unless f
        @format = f.to_s
      end

      def entity(name, &block)
        @entities ||= []
        entity = Entity.new(name)
        yield(entity) if block_given?
        if entity.format.blank? && !@format.blank?
          entity.format = @format
        end
        @entities << entity
      end
    end
    
    class Entity
      attr_accessor :name
      
      def initialize(name)
        @name = name
      end
      
      def format(f=nil)
        return @format if f.blank?
        self.format = f.to_s
      end
      
      def format=(f)
        raise 'Unsupported format' unless %w[xml json].include?(f.to_s)
        @format = f.to_s
      end
      
      def attributes(*names)
        return @attributes if names.blank?
        @attributes = names.flatten
      end
      
      def has_one(*items)
        @has_ones = items.flatten
      end
      
      def parse(body)
        send("from_#{format}", body)
      end
      
      def from_xml(body)
        Hash.from_xml(body)
      end
      
      def from_json(json)
        ActiveSupport::JSON.decode(json)
      end
    end
  end
end