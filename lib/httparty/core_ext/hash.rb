module HTTParty
  module CoreExt
    module HashConversions
      def to_struct
        o = OpenStruct.new
        self.each do |k, v|
          # if id, we create an accessor so we don't get warning about id deprecation
          if k.to_s == 'id'
            o.class.class_eval "attr_accessor :id"
            o.id = v
          else
            o.send("#{k}=", v.is_a?(Hash) ? v.to_struct : v)
          end
        end
        o
      end
    end
  end
end

Hash.send :include, HTTParty::CoreExt::HashConversions