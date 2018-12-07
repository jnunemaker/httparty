require 'delegate'

module HTTParty
  # Allow access to http_response and code by delegation on fragment
  class FragmentWithResponse < SimpleDelegator
    extend Forwardable

    attr_reader :http_response

    def code
      @http_response.code.to_i
    end

    def initialize(fragment, http_response)
      @fragment = fragment
      @http_response = http_response
      super fragment
    end
  end
end
