module Web
  module CoreExt
    module HashConversions
      def to_struct
        o = OpenStruct.new
        self.each do |k, v|
          o.send("#{k}=", v.is_a?(Hash) ? v.to_struct : v)
        end
        o
      end
    end
  end
end

Hash.send :include, Web::CoreExt::HashConversions