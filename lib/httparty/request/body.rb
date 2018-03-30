require_relative 'multipart_boundary'

module HTTParty
  class Request
    class Body
      def initialize(params, query_string_normalizer: nil)
        @params = params
        @query_string_normalizer = query_string_normalizer
      end

      def call
        if params.respond_to?(:to_hash)
          multipart? ? generate_multipart : normalize_query(params)
        else
          params
        end
      end

      def boundary
        @boundary ||= MultipartBoundary.generate
      end

      def multipart?
        params.respond_to?(:to_hash) && has_file?(params.to_hash)
      end

      private

      def generate_multipart
        normalized_params = params.flat_map { |key, value| HashConversions.normalize_keys(key, value) }

        multipart = normalized_params.inject('') do |memo, (key, value)|
          memo += "--#{boundary}\r\n"
          memo += %(Content-Disposition: form-data; name="#{key}")
          # value.path is used to support ActionDispatch::Http::UploadedFile
          # https://github.com/jnunemaker/httparty/pull/585
          memo += %(; filename="#{File.basename(value.path)}") if file?(value)
          memo += "\r\n"
          memo += "Content-Type: application/octet-stream\r\n" if file?(value)
          memo += "\r\n"
          memo += file?(value) ? value.read : value.to_s
          memo += "\r\n"
        end

        multipart += "--#{boundary}--\r\n"
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
        object.respond_to?(:path) && object.respond_to?(:read) # add memoization
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

      attr_reader :params, :query_string_normalizer
    end
  end
end
