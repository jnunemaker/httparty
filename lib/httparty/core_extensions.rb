module HTTParty
  if defined?(::BasicObject)
    BasicObject = ::BasicObject #:nodoc:
  else
    class BasicObject #:nodoc:
      instance_methods.each { |m| undef_method m unless m =~ /^__|instance_eval/ }
    end
  end

  unless defined?(Net::HTTP::Patch)
    class Net::HTTP
      def patch(path, data, initheader = nil, dest = nil, &block) #:nodoc:
        res = nil
        request(Patch.new(path, initheader), data) {|r|
          r.read_body dest, &block
          res = r
        }
        unless @newimpl
          res.value
          return res, res.body
        end
        res
      end

      class Patch < Net::HTTPRequest
        METHOD = 'PATCH'
        REQUEST_HAS_BODY = true
        RESPONSE_HAS_BODY = true
      end
    end
  end
end
