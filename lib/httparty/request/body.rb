require_relative 'multipart_boundary'

module HTTParty
  class Request
    class Body
      def initialize(params, query_string_normalizer: nil, force_multipart: false)
        @params = params
        @query_string_normalizer = query_string_normalizer
        @force_multipart = force_multipart
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
        params.respond_to?(:to_hash) && (force_multipart || has_file?(params))
      end

      private

      def generate_multipart
        normalized_params = params.flat_map { |key, value| HashConversions.normalize_keys(key, value) }

        multipart = normalized_params.inject('') do |memo, (key, value)|
          memo += "--#{boundary}\r\n"
          memo += %(Content-Disposition: form-data; name="#{key}")
          # value.path is used to support ActionDispatch::Http::UploadedFile
          # https://github.com/jnunemaker/httparty/pull/585
          memo += %(; filename="#{file_name(value)}") if file?(value)
          memo += "\r\n"
          memo += "Content-Type: #{content_type(value)}\r\n" if file?(value)
          memo += "\r\n"
          memo += file?(value) ? value.read : value.to_s
          memo += "\r\n"
        end

        multipart += "--#{boundary}--\r\n"
      end

      def has_file?(value)
        if value.respond_to?(:to_hash)
          value.to_hash.any? { |_, v| has_file?(v) }
        elsif value.respond_to?(:to_ary)
          value.to_ary.any? { |v| has_file?(v) }
        else
          file?(value)
        end
      end

      def file?(object)
        object.respond_to?(:path) && object.respond_to?(:read)
      end

      def normalize_query(query)
        if query_string_normalizer
          query_string_normalizer.call(query)
        else
          HashConversions.to_params(query)
        end
      end

      def content_type(object)
        return object.content_type if object.respond_to?(:content_type)
        mime = MIME::Types.type_for(object.path)
        mime.empty? ? 'application/octet-stream' : mime[0].content_type
      end

      def file_name(object)
        object.respond_to?(:original_filename) ? object.original_filename : File.basename(object.path)
      end

      attr_reader :params, :query_string_normalizer, :force_multipart
    end
  end
end
