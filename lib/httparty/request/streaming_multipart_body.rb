# frozen_string_literal: true

module HTTParty
  class Request
    class StreamingMultipartBody
      NEWLINE = "\r\n"
      CHUNK_SIZE = 64 * 1024 # 64 KB chunks

      def initialize(parts, boundary)
        @parts = parts
        @boundary = boundary
        @part_index = 0
        @state = :header
        @current_file = nil
        @header_buffer = nil
        @header_offset = 0
        @footer_sent = false
      end

      def size
        @size ||= calculate_size
      end

      def read(length = nil, outbuf = nil)
        outbuf = outbuf ? outbuf.replace(''.b) : ''.b

        return read_all(outbuf) if length.nil?

        while outbuf.bytesize < length
          chunk = read_chunk(length - outbuf.bytesize)
          break if chunk.nil?
          outbuf << chunk
        end

        outbuf.empty? ? nil : outbuf
      end

      def rewind
        @part_index = 0
        @state = :header
        @current_file = nil
        @header_buffer = nil
        @header_offset = 0
        @footer_sent = false
        @parts.each do |_key, value, _is_file|
          value.rewind if value.respond_to?(:rewind)
        end
      end

      private

      def read_all(outbuf)
        while (chunk = read_chunk(CHUNK_SIZE))
          outbuf << chunk
        end
        outbuf.empty? ? nil : outbuf
      end

      def read_chunk(max_length)
        loop do
          return nil if @part_index >= @parts.size && @footer_sent

          if @part_index >= @parts.size
            @footer_sent = true
            return "--#{@boundary}--#{NEWLINE}".b
          end

          key, value, is_file = @parts[@part_index]

          case @state
          when :header
            chunk = read_header_chunk(key, value, is_file, max_length)
            return chunk if chunk

          when :body
            chunk = read_body_chunk(value, is_file, max_length)
            return chunk if chunk

          when :newline
            @state = :header
            @part_index += 1
            return NEWLINE.b
          end
        end
      end

      def read_header_chunk(key, value, is_file, max_length)
        if @header_buffer.nil?
          @header_buffer = build_part_header(key, value, is_file)
          @header_offset = 0
        end

        remaining = @header_buffer.bytesize - @header_offset
        if remaining > 0
          chunk_size = [remaining, max_length].min
          chunk = @header_buffer.byteslice(@header_offset, chunk_size)
          @header_offset += chunk_size
          return chunk
        end

        @header_buffer = nil
        @header_offset = 0
        @state = :body
        nil
      end

      def read_body_chunk(value, is_file, max_length)
        if is_file
          chunk = read_file_chunk(value, max_length)
          if chunk
            return chunk
          else
            @current_file = nil
            @state = :newline
            return nil
          end
        else
          @state = :newline
          return value.to_s.b
        end
      end

      def read_file_chunk(file, max_length)
        chunk_size = [max_length, CHUNK_SIZE].min
        chunk = file.read(chunk_size)
        return nil if chunk.nil?
        chunk.force_encoding(Encoding::BINARY) if chunk.respond_to?(:force_encoding)
        chunk
      end

      def build_part_header(key, value, is_file)
        header = "--#{@boundary}#{NEWLINE}".b
        header << %(Content-Disposition: form-data; name="#{key}").b
        if is_file
          header << %(; filename="#{file_name(value).gsub(/["\r\n]/, replacement_table)}").b
          header << NEWLINE.b
          header << "Content-Type: #{content_type(value)}#{NEWLINE}".b
        else
          header << NEWLINE.b
        end
        header << NEWLINE.b
        header
      end

      def calculate_size
        total = 0
        @parts.each do |key, value, is_file|
          total += build_part_header(key, value, is_file).bytesize
          total += content_size(value, is_file)
          total += NEWLINE.bytesize
        end
        total += "--#{@boundary}--#{NEWLINE}".bytesize
        total
      end

      def content_size(value, is_file)
        if is_file
          if value.respond_to?(:size)
            value.size
          elsif value.respond_to?(:stat)
            value.stat.size
          else
            value.read.bytesize.tap { value.rewind }
          end
        else
          value.to_s.b.bytesize
        end
      end

      def content_type(object)
        return object.content_type if object.respond_to?(:content_type)
        require 'mini_mime'
        mime = MiniMime.lookup_by_filename(object.path)
        mime ? mime.content_type : 'application/octet-stream'
      end

      def file_name(object)
        object.respond_to?(:original_filename) ? object.original_filename : File.basename(object.path)
      end

      def replacement_table
        @replacement_table ||= {
          '"'  => '%22',
          "\r" => '%0D',
          "\n" => '%0A'
        }.freeze
      end
    end
  end
end
