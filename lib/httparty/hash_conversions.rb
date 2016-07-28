require 'erb'

module HTTParty
  module HashConversions
    # @return <String> This hash as a query string
    #
    # @example
    #   { name: "Bob",
    #     address: {
    #       street: '111 Ruby Ave.',
    #       city: 'Ruby Central',
    #       phones: ['111-111-1111', '222-222-2222']
    #     }
    #   }.to_params
    #     #=> "name=Bob&address[city]=Ruby Central&address[phones][]=111-111-1111&address[phones][]=222-222-2222&address[street]=111 Ruby Ave."
    def self.to_params(hash)
      hash.to_hash.map { |k, v| normalize_param(k, v) }.join.chop
    end

    # @param key<Object> The key for the param.
    # @param value<Object> The value for the param.
    #
    # @return <String> This key value pair as a param
    #
    # @example normalize_param(:name, "Bob Jones") #=> "name=Bob%20Jones&"
    def self.normalize_param(key, value)
      param = ''
      stack = []

      if value.respond_to?(:to_ary)
        param << if value.empty?
                   "#{key}[]=&"
                 else
                   value.to_ary.map { |element| normalize_param("#{key}[]", element) }.join
                 end
      elsif value.respond_to?(:to_hash)
        stack << [key, value.to_hash]
      else
        param << "#{key}=#{ERB::Util.url_encode(value.to_s)}&"
      end

      stack.each do |parent, hash|
        hash.each do |k, v|
          if v.respond_to?(:to_hash)
            stack << ["#{parent}[#{k}]", v.to_hash]
          else
            param << normalize_param("#{parent}[#{k}]", v)
          end
        end
      end

      param
    end
  end
end
