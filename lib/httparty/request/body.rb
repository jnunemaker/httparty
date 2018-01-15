require 'pry'

module HTTParty
  class Request
    class Body
      def initialize(params, query_string_normalizer: nil)
        @params = params
        @query_string_normalizer = query_string_normalizer
        @options = {}
      end

      def call
        if params.respond_to?(:to_hash)
          multipart? ? generate_multipart : normalize_query(params)
        else
          params
        end
      end

      private

      def generate_multipart
      end

      def multipart?
        options[:multipart] || has_file?(params)
      end

      def has_file?(hash)
        hash.detect do |key, value|
          if value.respond_to?(:to_hash) || includes_hash?(value)
            has_file?(value)
          elsif value.respond_to?(:to_ary)
            value.any? { |e| file?(e) }
          else
            file?(value)
          end
        end
      end

      def file?(object)
        object.respond_to?(:path) && object.respond_to?(:read)
      end

      def includes_hash?(object)
        object.respond_to?(:to_ary) && object.any? { |e| e.respond_to?(:hash) }
      end

      def normalize_query(query)
        if query_string_normalizer
          query_string_normalizer.call(query)
        else
          HashConversions.to_params(query)
        end
      end

      def boundary
        @boundary ||= "--------------------------#{SecureRandom.urlsafe_base64(12)}"
      end

      attr_reader :params, :query_string_normalizer, :options
    end
  end
end
